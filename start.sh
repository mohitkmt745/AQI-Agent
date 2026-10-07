#!/usr/bin/env bash
# start.sh — container entrypoint
# Ingests the RAG knowledge base (idempotent), then starts FastAPI and
# Streamlit as background processes, keeping the container alive.

set -e

echo "==> Ingesting knowledge base (idempotent) …"
python -m rag.ingest

echo "==> Starting FastAPI backend on port ${API_PORT:-8000} …"
uvicorn api.main:app \
    --host "${API_HOST:-0.0.0.0}" \
    --port "${API_PORT:-8000}" \
    --workers 2 \
    --log-level info &
API_PID=$!

echo "==> Starting Streamlit dashboard on port 8501 …"
streamlit run dashboard/app.py \
    --server.port 8501 \
    --server.address 0.0.0.0 \
    --server.headless true \
    --browser.gatherUsageStats false &
STREAMLIT_PID=$!

echo "==> AirAction is running."
echo "    API:       http://localhost:${API_PORT:-8000}/docs"
echo "    Dashboard: http://localhost:8501"

# Wait for either process to exit; exit with its code
wait -n $API_PID $STREAMLIT_PID
exit $?
