"""RAG knowledge base for the Sage chatbot (Retrieval-Augmented Generation).

What goes in: Academy lessons, app guide and methodology (app/knowledge/*.md),
the latest news with sentiment, and the latest AI signal for each coin.

Search engine, best available first:
1. Dense: sentence-transformers embeddings (all-MiniLM-L6-v2) stored in ChromaDB
   -> finds text with the same MEANING ("coin crash" finds "prices plunge").
2. Sparse: TF-IDF keyword search (scikit-learn) -> works with no extra installs.
"""
import hashlib
import json
import logging
import re
import threading
from pathlib import Path

import numpy as np

from ..config import settings

log = logging.getLogger("cryptosense.rag")
KNOWLEDGE_DIR = Path(__file__).resolve().parents[1] / "knowledge"


def _id(text: str) -> str:
    return hashlib.md5(text.encode()).hexdigest()[:16]


def load_markdown_docs() -> list[dict]:
    """Split every knowledge/*.md file into one document per '## ' section."""
    docs = []
    for path in sorted(KNOWLEDGE_DIR.glob("*.md")):
        for block in re.split(r"\n(?=## )", path.read_text(encoding="utf-8")):
            block = block.strip()
            if not block.startswith("## "):
                continue
            title, _, body = block[3:].partition("\n")
            docs.append({"id": f"kb:{path.stem}:{_id(title)}", "text": f"{title}. {body.strip()}",
                         "meta": {"kind": path.stem, "title": title.strip(), "url": ""}})
    return docs


class _Dense:
    """ChromaDB + sentence-transformers."""
    name = "dense (MiniLM + ChromaDB)"

    def __init__(self):
        import chromadb
        from sentence_transformers import SentenceTransformer
        self.model = SentenceTransformer(settings.embed_model)
        client = chromadb.PersistentClient(path=settings.rag_dir)
        self.col = client.get_or_create_collection("cryptosense", metadata={"hnsw:space": "cosine"})

    def upsert(self, docs: list[dict]) -> None:
        if not docs:
            return
        vecs = self.model.encode([d["text"] for d in docs], normalize_embeddings=True).tolist()
        self.col.upsert(ids=[d["id"] for d in docs], documents=[d["text"] for d in docs],
                        metadatas=[d["meta"] for d in docs], embeddings=vecs)

    def search(self, query: str, k: int) -> list[dict]:
        if self.col.count() == 0:
            return []
        q = self.model.encode([query], normalize_embeddings=True).tolist()
        r = self.col.query(query_embeddings=q, n_results=min(k, self.col.count()))
        return [{"text": t, "meta": m, "score": round(1 - d, 3)}
                for t, m, d in zip(r["documents"][0], r["metadatas"][0], r["distances"][0])]

    def count(self) -> int:
        return self.col.count()


class _Sparse:
    """TF-IDF keyword search, saved to a JSON file."""
    name = "sparse (TF-IDF)"

    def __init__(self):
        self.path = Path(settings.rag_dir) / "tfidf_docs.json"
        self.docs: dict[str, dict] = {}
        if self.path.exists():
            self.docs = json.loads(self.path.read_text(encoding="utf-8"))
        self._vec = self._mat = None
        self._ids: list[str] = []

    def _refit(self):
        from sklearn.feature_extraction.text import TfidfVectorizer
        self._ids = list(self.docs)
        if not self._ids:
            self._vec = self._mat = None
            return
        self._vec = TfidfVectorizer(stop_words="english", ngram_range=(1, 2), sublinear_tf=True)
        self._mat = self._vec.fit_transform([self.docs[i]["text"] for i in self._ids])

    def upsert(self, docs: list[dict]) -> None:
        for d in docs:
            self.docs[d["id"]] = {"text": d["text"], "meta": d["meta"]}
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps(self.docs), encoding="utf-8")
        self._vec = None

    def search(self, query: str, k: int) -> list[dict]:
        if self._vec is None:
            self._refit()
        if self._vec is None:
            return []
        sims = (self._mat @ self._vec.transform([query]).T).toarray().ravel()
        top = np.argsort(-sims)[:k]
        return [{"text": self.docs[self._ids[i]]["text"], "meta": self.docs[self._ids[i]]["meta"],
                 "score": round(float(sims[i]), 3)} for i in top if sims[i] > 0]

    def count(self) -> int:
        return len(self.docs)


class KnowledgeBase:
    def __init__(self):
        self._store = None
        self._lock = threading.Lock()

    @property
    def store(self):
        with self._lock:
            if self._store is None:
                try:
                    self._store = _Dense()
                except Exception as e:
                    log.info("Dense RAG not available (%s); using TF-IDF", e.__class__.__name__)
                    self._store = _Sparse()
                log.info("RAG backend: %s", self._store.name)
            return self._store

    def build_static(self) -> int:
        docs = load_markdown_docs()
        self.store.upsert(docs)
        return len(docs)

    def upsert_news(self, items: list[dict]) -> None:
        docs = [{
            "id": f"news:{_id(i['title'])}",
            "text": f"{i['title']}. {i['summary']} Sentiment: {i.get('sentiment', 'unknown')}. "
                    f"Coins: {', '.join(i.get('coins', []))}. Published {i['published_at'][:16]} by {i['source']}.",
            "meta": {"kind": "news", "title": i["title"], "url": i.get("url") or "",
                     "published_at": i["published_at"], "source": i["source"]},
        } for i in items if i.get("title")]
        self.store.upsert(docs)

    def upsert_signals(self, signals: list[dict]) -> None:
        docs = [{
            "id": f"signal:{s['symbol']}",
            "text": f"AI signal for {s['symbol'].replace('USDT', '')} ({s['symbol']}): {s['trend']} with "
                    f"{s['confidence'] * 100:.0f}% confidence for the {s['horizon'].lower()}, by {s['model']}. "
                    f"Reasons: {' '.join(s['reasons'])} Generated {s['generated_at'][:16]} UTC.",
            "meta": {"kind": "signal", "title": f"AI signal: {s['symbol']}", "url": "",
                     "published_at": s["generated_at"]},
        } for s in signals]
        self.store.upsert(docs)

    def search(self, query: str, k: int | None = None) -> list[dict]:
        return self.store.search(query, k or settings.rag_top_k)

    def status(self) -> dict:
        return {"backend": self.store.name, "documents": self.store.count()}


kb = KnowledgeBase()