"""Train the CryptoSense AI market-state models.
    python -m ml.train                 # real data: Binance candles + funding, Fear & Greed (needs internet)
    python -m ml.train --demo          # synthetic data, offline test only
    python -m ml.train --no-gru        # skip the deep-learning model (if PyTorch isn't installed)
"""
import argparse
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
import httpx
import joblib
import lightgbm as lgb
import numpy as np
import pandas as pd
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, f1_score
from sklearn.utils.class_weight import compute_sample_weight
from xgboost import XGBClassifier
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from app.config import settings  # noqa: E402
from app.services import demo  # noqa: E402
from app.services.binance import funding_frame, to_frame  # noqa: E402
from app.services.deep import TORCH, WINDOW  # noqa: E402
from app.services.features import FEATURES, LABELS, add_features, add_labels, merge_context  # noqa: E402
from app.services.sentiment_index import fng_frame  # noqa: E402
MODEL_DIR = ROOT / "ml" / "models"
NAMES = {"xgb": "XGBoost", "lgbm": "LightGBM", "gru": "GRU", "ensemble": "Ensemble"}
def _ms(days_ago: float) -> int:
    return int((time.time() - days_ago * 86400) * 1000)
def download_klines(symbol: str, days: int) -> pd.DataFrame:
    start, rows = _ms(days), []
    with httpx.Client(base_url=settings.binance_base, timeout=30) as c:
        while True:
            r = c.get("/api/v3/klines", params={"symbol": symbol, "interval": "1h", "startTime": start, "limit": 1000})
            r.raise_for_status()
            batch = r.json()
            if not batch:
                break
            rows.extend(batch)
            start = batch[-1][0] + 1
            if len(batch) < 1000:
                break
            time.sleep(0.15)
    return to_frame(rows)
def download_funding(symbol: str, days: int) -> pd.DataFrame | None:
    start, rows = _ms(days + 3), []
    try:
        with httpx.Client(base_url=settings.binance_futures_base, timeout=30) as c:
            while True:
                r = c.get("/fapi/v1/fundingRate", params={"symbol": symbol, "startTime": start, "limit": 1000})
                r.raise_for_status()
                batch = r.json()
                if not batch:
                    break
                rows.extend(batch)
                start = int(batch[-1]["fundingTime"]) + 1
                if len(batch) < 1000:
                    break
                time.sleep(0.15)
        return funding_frame(rows)
    except Exception as e:
        print(f"    (no funding data for {symbol}: {e.__class__.__name__}; using neutral value)")
        return None
def download_fng() -> pd.DataFrame | None:
    try:
        r = httpx.get(settings.fear_greed_url, params={"limit": 0}, timeout=30)
        r.raise_for_status()
        return fng_frame(r.json()["data"])
    except Exception as e:
        print(f"  (Fear & Greed unavailable: {e.__class__.__name__}; using neutral value)")
        return None
def load_data(args) -> list[pd.DataFrame]:
    tables = []
    if args.demo:
        n = args.days * 24
        btc = demo.candles("BTCUSDT", n, seed=1)
        fng = demo.fear_greed(btc["time"])
        for i, symbol in enumerate(settings.symbol_list):
            df = btc if symbol == "BTCUSDT" else demo.candles(symbol, n, seed=i + 1)
            tables.append((symbol, df, demo.funding(df["time"], seed=i + 10), fng, btc))
    else:
        print("  downloading Fear & Greed history ...")
        fng = download_fng()
        print("  downloading BTCUSDT (market context) ...")
        btc = download_klines("BTCUSDT", args.days)
        for symbol in settings.symbol_list:
            print(f"  downloading {symbol} ...", end=" ", flush=True)
            df = btc if symbol == "BTCUSDT" else download_klines(symbol, args.days)
            print(f"{len(df)} candles")
            tables.append((symbol, df, download_funding(symbol, args.days), fng, btc))
    out = []
    for symbol, df, funding, fng, btc in tables:
        data = add_labels(add_features(merge_context(df, funding, fng, btc)), args.horizon, args.threshold)
        data = data.dropna(subset=FEATURES + ["label"]).reset_index(drop=True)
        data["label"] = data["label"].astype(int)
        data["symbol"] = symbol
        out.append(data)
    return out
def split_ranges(n: int, gap: int) -> dict:
    a, b = int(n * 0.70), int(n * 0.85)
    return {"train": (0, max(a - gap, 0)), "val": (a, max(b - gap, a)), "test": (b, n)}
def report(name: str, y: np.ndarray, proba: np.ndarray) -> dict:
    pred = proba.argmax(1)
    acc, f1 = accuracy_score(y, pred), f1_score(y, pred, average="macro")
    conf = proba.max(1)
    sure = conf >= 0.5
    print(f"\n=== {name} ===  accuracy {acc:.3f}   macro F1 {f1:.3f}")
    print(classification_report(y, pred, labels=[0, 1, 2], target_names=[LABELS[i] for i in range(3)],
                                digits=3, zero_division=0))
    cm = confusion_matrix(y, pred, labels=[0, 1, 2])
    print("confusion matrix (rows = actual bearish / neutral / bullish):\n", cm)
    return {
        "accuracy": round(float(acc), 4),
        "macro_f1": round(float(f1), 4),
        "confident_accuracy": round(float(accuracy_score(y[sure], pred[sure])), 4) if sure.any() else None,
        "confident_coverage": round(float(sure.mean()), 4),
        "confusion_matrix": cm.tolist(),
    }
def train_gru(tables, ranges, args):
    import torch
    from torch import nn
    from torch.utils.data import DataLoader, Dataset
    from app.services.deep import GRUModel, GRUNet
    torch.manual_seed(42)
    np.random.seed(42)
    train_rows = np.concatenate([t[FEATURES].to_numpy()[r["train"][0]:r["train"][1]] for t, r in zip(tables, ranges)])
    mean, std = train_rows.mean(0), train_rows.std(0) + 1e-8
    arrays = [((t[FEATURES].to_numpy() - mean) / std).astype(np.float32) for t in tables]
    labels = [t["label"].to_numpy().astype(np.int64) for t in tables]
    def index(part):
        return [(k, i) for k, r in enumerate(ranges) for i in range(max(r[part][0], WINDOW - 1), r[part][1])]
    class Windows(Dataset):
        def __init__(self, idx):
            self.idx = idx
        def __len__(self):
            return len(self.idx)
        def __getitem__(self, j):
            k, i = self.idx[j]
            return torch.from_numpy(arrays[k][i - WINDOW + 1: i + 1]), int(labels[k][i])
    train_idx, val_idx, test_idx = index("train"), index("val"), index("test")
    train_dl = DataLoader(Windows(train_idx), batch_size=256, shuffle=True)
    y_train = np.array([labels[k][i] for k, i in train_idx])
    counts = np.bincount(y_train, minlength=3).astype(np.float32)
    class_w = torch.tensor(len(y_train) / (3 * np.maximum(counts, 1)), dtype=torch.float32)
    net = GRUNet(len(FEATURES), hidden=args.gru_hidden)
    opt = torch.optim.Adam(net.parameters(), lr=1e-3, weight_decay=1e-5)
    loss_fn = nn.CrossEntropyLoss(weight=class_w)
    def predict(idx):
        net.eval()
        out = []
        with torch.no_grad():
            for xb, _ in DataLoader(Windows(idx), batch_size=1024):
                out.append(torch.softmax(net(xb), dim=1).numpy())
        return np.concatenate(out)
    y_val = np.array([labels[k][i] for k, i in val_idx])
    best_f1, best_state, bad = -1.0, None, 0
    for epoch in range(1, args.epochs + 1):
        net.train()
        t0, total = time.time(), 0.0
        for xb, yb in train_dl:
            opt.zero_grad()
            loss = loss_fn(net(xb), yb)
            loss.backward()
            nn.utils.clip_grad_norm_(net.parameters(), 1.0)
            opt.step()
            total += float(loss) * len(yb)
        f1 = f1_score(y_val, predict(val_idx).argmax(1), average="macro")
        print(f"  epoch {epoch:2d}  loss {total / len(train_idx):.4f}  val macro-F1 {f1:.4f}  ({time.time() - t0:.0f}s)")
        if f1 > best_f1:
            best_f1, best_state, bad = f1, {k: v.clone() for k, v in net.state_dict().items()}, 0
        else:
            bad += 1
            if bad >= args.patience:
                print("  early stopping")
                break
    net.load_state_dict(best_state)
    net.eval()
    return GRUModel(net, mean, std, FEATURES), predict(val_idx), predict(test_idx)
def main() -> None:
    p = argparse.ArgumentParser(description="Train CryptoSense AI models")
    p.add_argument("--days", type=int, default=730)
    p.add_argument("--horizon", type=int, default=24)
    p.add_argument("--threshold", type=float, default=1.5)
    p.add_argument("--epochs", type=int, default=15)
    p.add_argument("--patience", type=int, default=4)
    p.add_argument("--gru-hidden", type=int, default=64)
    p.add_argument("--no-gru", action="store_true")
    p.add_argument("--demo", action="store_true")
    args = p.parse_args()
    print(f"Building dataset ({'DEMO' if args.demo else 'live Binance'} data, {args.days} days, "
          f"horizon {args.horizon}h, threshold {args.threshold}%)")
    tables = load_data(args)
    gap = max(args.horizon, WINDOW)
    ranges = [split_ranges(len(t), gap) for t in tables]
    def part(name):
        return pd.concat([t.iloc[r[name][0]:r[name][1]] for t, r in zip(tables, ranges)])
    tr, va, te = part("train"), part("val"), part("test")
    X_tr, y_tr = tr[FEATURES], tr["label"].to_numpy()
    X_va, y_va = va[FEATURES], va["label"].to_numpy()
    X_te, y_te = te[FEATURES], te["label"].to_numpy()
    balance = {LABELS[k]: int(v) for k, v in zip(*np.unique(y_tr, return_counts=True))}
    print(f"rows: train {len(X_tr)}, validation {len(X_va)}, test {len(X_te)}; train classes {balance}")
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    for old in ("rf.joblib", "svm.joblib", "gru.pt"):
        (MODEL_DIR / old).unlink(missing_ok=True)
    val_proba, test_proba, results = {}, {}, {}
    print("\nTraining XGBoost ...")
    xgb = XGBClassifier(n_estimators=800, max_depth=4, learning_rate=0.03, subsample=0.8, colsample_bytree=0.8,
                        min_child_weight=5, objective="multi:softprob", num_class=3, eval_metric="mlogloss",
                        early_stopping_rounds=50, n_jobs=-1, random_state=42)
    xgb.fit(X_tr, y_tr, sample_weight=compute_sample_weight("balanced", y_tr), eval_set=[(X_va, y_va)], verbose=False)
    val_proba["xgb"], test_proba["xgb"] = xgb.predict_proba(X_va), xgb.predict_proba(X_te)
    joblib.dump(xgb, MODEL_DIR / "xgb.joblib")
    print("Training LightGBM ...")
    lgbm = lgb.LGBMClassifier(n_estimators=1000, learning_rate=0.03, num_leaves=31, min_child_samples=50,
                              subsample=0.8, subsample_freq=1, colsample_bytree=0.8, class_weight="balanced",
                              random_state=42, verbose=-1)
    lgbm.fit(X_tr, y_tr, eval_set=[(X_va, y_va)], callbacks=[lgb.early_stopping(50, verbose=False)])
    val_proba["lgbm"], test_proba["lgbm"] = lgbm.predict_proba(X_va), lgbm.predict_proba(X_te)
    joblib.dump(lgbm, MODEL_DIR / "lgbm.joblib")
    if args.no_gru:
        print("Skipping GRU (--no-gru).")
    elif not TORCH:
        print("Skipping GRU: PyTorch is not installed (see requirements-ai.txt).")
    else:
        print(f"\nTraining GRU (window {WINDOW}h, up to {args.epochs} epochs) ...")
        gru, val_proba["gru"], test_proba["gru"] = train_gru(tables, ranges, args)
        gru.save(MODEL_DIR / "gru.pt")
    weights = {k: round(float(f1_score(y_va, v.argmax(1), average="macro")), 4) for k, v in val_proba.items()}
    wsum = sum(weights.values())
    val_proba["ensemble"] = sum(weights[k] * val_proba[k] for k in weights) / wsum
    test_proba["ensemble"] = sum(weights[k] * test_proba[k] for k in weights) / wsum
    for key in test_proba:
        results[key] = report(NAMES[key], y_te, test_proba[key])
    majority = int(np.bincount(y_tr, minlength=3).argmax())
    base_pred = np.full_like(y_te, majority)
    results["baseline_majority"] = {
        "accuracy": round(float(accuracy_score(y_te, base_pred)), 4),
        "macro_f1": round(float(f1_score(y_te, base_pred, average="macro")), 4),
    }
    print(f"\nBaseline (always '{LABELS[majority]}'): accuracy {results['baseline_majority']['accuracy']:.3f}, "
          f"macro F1 {results['baseline_majority']['macro_f1']:.3f}")
    importance = pd.Series(xgb.feature_importances_, index=FEATURES).sort_values(ascending=False)
    metrics = {
        "trained_at": datetime.now(timezone.utc).isoformat(),
        "data": "demo" if args.demo else "binance",
        "symbols": settings.symbol_list,
        "days": args.days, "interval": "1h",
        "horizon_hours": args.horizon, "threshold_pct": args.threshold,
        "features": FEATURES,
        "split": "chronological 70/15/15 per coin with gaps",
        "rows": {"train": int(len(X_tr)), "validation": int(len(X_va)), "test": int(len(X_te))},
        "class_balance_train": balance,
        "ensemble_weights": weights,
        "results": results,
        "feature_importance_xgb": {k: round(float(v), 4) for k, v in importance.items()},
    }
    (MODEL_DIR / "metrics.json").write_text(json.dumps(metrics, indent=2))
    print("\nSummary (test set, macro F1):")
    for k, r in results.items():
        print(f"  {NAMES.get(k, 'Baseline'):10s} {r['macro_f1']:.3f}   accuracy {r['accuracy']:.3f}")
    print(f"Saved to {MODEL_DIR}")
    if args.demo:
        print("NOTE: synthetic data. Run without --demo for real results.")
if __name__ == "__main__":
    main()
