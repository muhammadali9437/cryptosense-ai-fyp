"""Deep-learning model: a GRU (Gated Recurrent Unit) network.

Tree models (XGBoost, LightGBM) look at one moment. The GRU reads the last WINDOW hours
as a sequence, so it can learn how a pattern developed. Needs PyTorch
(requirements-ai.txt); if PyTorch is missing the rest of the app still works.
"""
from pathlib import Path

import numpy as np
import pandas as pd

try:
    import torch
    from torch import nn
    TORCH = True
except Exception:  # torch not installed
    TORCH = False

WINDOW = 48  # hours of history the GRU reads


if TORCH:
    class GRUNet(nn.Module):
        """2-layer GRU -> dropout -> linear layer with 3 outputs (bearish, neutral, bullish)."""

        def __init__(self, n_features: int, hidden: int = 64, layers: int = 2, dropout: float = 0.2):
            super().__init__()
            self.gru = nn.GRU(n_features, hidden, num_layers=layers, batch_first=True,
                              dropout=dropout if layers > 1 else 0.0)
            self.head = nn.Sequential(nn.Dropout(dropout), nn.Linear(hidden, 3))

        def forward(self, x):  # x: (batch, WINDOW, n_features)
            out, _ = self.gru(x)
            return self.head(out[:, -1, :])  # use the last time step


class GRUModel:
    """Wraps the trained network + the scaling numbers it was trained with."""

    def __init__(self, net, mean: np.ndarray, std: np.ndarray, features: list[str], window: int = WINDOW):
        self.net, self.mean, self.std, self.features, self.window = net, mean, std, features, window

    def _scale(self, x: np.ndarray) -> np.ndarray:
        return ((x - self.mean) / self.std).astype(np.float32)

    def predict_proba_window(self, feats: pd.DataFrame) -> np.ndarray | None:
        """feats = feature rows in time order; uses the last `window` rows."""
        if len(feats) < self.window:
            return None
        x = self._scale(feats[self.features].to_numpy()[-self.window:])
        with torch.no_grad():
            logits = self.net(torch.from_numpy(x)[None])
            return torch.softmax(logits, dim=1).numpy()[0]

    def save(self, path: Path) -> None:
        torch.save({
            "state": self.net.state_dict(), "mean": self.mean, "std": self.std,
            "features": self.features, "window": self.window,
            "hidden": self.net.gru.hidden_size, "layers": self.net.gru.num_layers,
        }, path)

    @staticmethod
    def load(path: Path) -> "GRUModel | None":
        if not TORCH or not path.exists():
            return None
        ckpt = torch.load(path, map_location="cpu", weights_only=False)
        net = GRUNet(len(ckpt["features"]), ckpt["hidden"], ckpt["layers"])
        net.load_state_dict(ckpt["state"])
        net.eval()
        return GRUModel(net, ckpt["mean"], ckpt["std"], ckpt["features"], ckpt["window"])