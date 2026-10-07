# ── AirAction Dockerfile ───────────────────────────────────────────────────
# Multi-stage build: builds Python dependencies in an isolated stage,
# then copies only what is needed into the final slim runtime image.
# The image exposes both the FastAPI backend (port 8000) and the
# Streamlit dashboard (port 8501) and uses a start script to launch both.
#
# Build:
#   docker build -t airaction:latest .
#
# Run locally:
#   docker run --env-file .env -p 8000:8000 -p 8501:8501 airaction:latest
# ─────────────────────────────────────────────────────────────────────────────

# ── Stage 1: dependency builder ───────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# System deps needed to compile Prophet / scikit-learn / numpy wheels
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc g++ libffi-dev libssl-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --upgrade pip \
    && pip install --prefix=/install --no-cache-dir -r requirements.txt


# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application source
COPY agents/   ./agents/
COPY rag/      ./rag/
COPY api/      ./api/
COPY dashboard/ ./dashboard/
COPY data/     ./data/

# Copy startup script (created below)
COPY start.sh .
RUN chmod +x start.sh

# ChromaDB persistence volume (mount at runtime for durability)
VOLUME ["/app/chroma_db"]

# Expose FastAPI + Streamlit ports
EXPOSE 8000 8501

# Environment variable defaults (override with --env-file or -e)
ENV API_HOST=0.0.0.0 \
    API_PORT=8000 \
    CHROMA_DB_PATH=/app/chroma_db \
    USE_SAMPLE_DATA=false

# Ingest knowledge base on first run, then start both services
CMD ["./start.sh"]
