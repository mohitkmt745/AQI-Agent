# 🌬️ AirAction — AI-Powered Daily Air Quality Action Agent

> **Turn real-time air quality data into simple, actionable daily guidance for citizens,
> policymakers, and organizations — powered by IBM Granite on watsonx.ai.**

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Folder Structure](#folder-structure)
4. [Prerequisites](#prerequisites)
5. [Local Setup](#local-setup)
6. [Running the Application](#running-the-application)
7. [IBM Cloud Deployment](#ibm-cloud-deployment)
8. [Environment Variables](#environment-variables)
9. [Agents Reference](#agents-reference)
10. [API Reference](#api-reference)
11. [Disclaimer](#disclaimer)

---

## Overview

AirAction is a multi-agent AI system that:

- Fetches **real-time AQI and pollutant data** (PM2.5, PM10, NO₂, O₃, CO, SO₂) for any city
- Uses **RAG** (Retrieval-Augmented Generation) over a knowledge base of AQI guidelines to explain data in plain English via IBM Granite
- Generates **personalised daily health actions** based on the user's age group and health conditions
- Forecasts **72-hour AQI trends** using Facebook Prophet with early warnings
- Suggests **community and policy actions** and generates social-media awareness posts
- Serves everything via a **FastAPI backend** and a **Streamlit dashboard**

---

## Architecture

```
Streamlit Dashboard ──REST──► FastAPI Gateway ──► Coordinator Agent
                                                        │
                              ┌─────────────────────────┼────────────────────┐
                              ▼                         ▼                    ▼ ▼
                       AQI Data Agent          Health Advisory        Forecast  Community
                       (WAQI / OpenAQ)          Agent (Granite)        Agent     Agent
                              │
                        RAG Pipeline
                        (ChromaDB + sentence-transformers + Granite)
```

---

## Folder Structure

```
AirAction/
├── agents/
│   ├── __init__.py
│   ├── aqi_agent.py          # Fetch AQI + RAG explanation
│   ├── health_agent.py       # Personalised health advice
│   ├── forecast_agent.py     # 72-hour AQI forecast
│   ├── community_agent.py    # Community + policy actions
│   ├── coordinator.py        # Orchestrates all agents
│   └── granite_client.py     # IBM Granite (watsonx.ai) wrapper
├── rag/
│   ├── __init__.py
│   ├── pipeline.py           # Chunk → embed → store → retrieve
│   └── ingest.py             # One-time KB ingestion script
├── api/
│   ├── __init__.py
│   └── main.py               # FastAPI endpoints
├── dashboard/
│   └── app.py                # Streamlit UI
├── data/
│   ├── knowledge_base/       # AQI guidelines text files
│   ├── historical/           # CSV historical AQI data
│   └── sample/               # Fallback JSON sample data
├── .env.example              # Template for environment variables
├── .dockerignore
├── Dockerfile                # Multi-stage Docker build
├── start.sh                  # Container entrypoint
├── ibm_cloud_deploy.yaml     # IBM Cloud Code Engine manifest
└── requirements.txt
```

---

## Prerequisites

| Requirement | Version |
|---|---|
| Python | 3.11+ |
| pip | 23+ |
| IBM Cloud account | — |
| watsonx.ai project | — |
| WAQI API key (free) | [aqicn.org/api](https://aqicn.org/api/) |
| Docker (for containerised deploy) | 24+ |
| IBM Cloud CLI + Code Engine plugin | latest |

---

## Local Setup

### 1. Clone and enter the project

```bash
git clone <your-repo-url>
cd AirAction
```

### 2. Create a virtual environment

```bash
python -m venv .venv
# Windows
.venv\Scripts\activate
# macOS / Linux
source .venv/bin/activate
```

### 3. Install dependencies

```bash
pip install -r requirements.txt
```

> **Note:** Prophet requires `pystan` which may need a C++ compiler.
> On Windows install [Microsoft C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
> before running `pip install`.

### 4. Configure environment variables

```bash
cp .env.example .env
# Edit .env and fill in your keys
```

Minimum required keys:

```
WATSONX_API_KEY=...
WATSONX_PROJECT_ID=...
WAQI_API_KEY=...
```

To run without any external APIs (sample data + no Granite), set:

```
USE_SAMPLE_DATA=true
# Leave WATSONX_API_KEY blank to use the placeholder response
```

### 5. Ingest the knowledge base (one-time)

```bash
python -m rag.ingest
```

This chunks the text files in `data/knowledge_base/`, embeds them with
`all-MiniLM-L6-v2`, and stores them in ChromaDB at `./chroma_db/`.
Re-run any time you update the knowledge base files.

---

## Running the Application

### Start the FastAPI backend

```bash
uvicorn api.main:app --reload --host 0.0.0.0 --port 8000
```

Interactive API docs: [http://localhost:8000/docs](http://localhost:8000/docs)

### Start the Streamlit dashboard

In a separate terminal (with the same `.venv` activated):

```bash
streamlit run dashboard/app.py
```

Dashboard: [http://localhost:8501](http://localhost:8501)

---

## IBM Cloud Deployment

### Step 1 — Build and push the Docker image

```bash
# Log in to IBM Cloud Container Registry
ibmcloud login --sso
ibmcloud cr login
ibmcloud cr namespace-add airaction

# Build and push
docker build -t us.icr.io/airaction/airaction:latest .
docker push us.icr.io/airaction/airaction:latest
```

### Step 2 — Create secrets in Code Engine

```bash
ibmcloud ce project create --name airaction-project
ibmcloud ce project select --name airaction-project

ibmcloud ce secret create --name airaction-secrets \
  --from-literal WATSONX_API_KEY=<your_key> \
  --from-literal WATSONX_PROJECT_ID=<your_project> \
  --from-literal WAQI_API_KEY=<your_waqi_key>
```

### Step 3 — Deploy the application

```bash
ibmcloud ce application create \
  --name airaction \
  --image us.icr.io/airaction/airaction:latest \
  --port 8000 \
  --env-from-secret airaction-secrets \
  --env USE_SAMPLE_DATA=false \
  --min-scale 1 \
  --max-scale 5 \
  --cpu 1 \
  --memory 2G
```

### Step 4 — Get the public URL

```bash
ibmcloud ce application get --name airaction --output url
```

### Step 5 — Point the dashboard at the deployed API

Set `API_BASE_URL` in your Streamlit deployment (or a second Code Engine app):

```bash
ibmcloud ce application create \
  --name airaction-dashboard \
  --image us.icr.io/airaction/airaction:latest \
  --port 8501 \
  --env API_BASE_URL=https://<airaction-api-url> \
  --env-from-secret airaction-secrets
```

---

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `WATSONX_API_KEY` | ✅ | — | IBM watsonx.ai API key |
| `WATSONX_PROJECT_ID` | ✅ | — | watsonx.ai project ID |
| `WATSONX_URL` | ❌ | `https://us-south.ml.cloud.ibm.com` | watsonx.ai endpoint |
| `GRANITE_MODEL_ID` | ❌ | `ibm/granite-13b-instruct-v2` | Granite model to use |
| `WAQI_API_KEY` | ✅ | — | World Air Quality Index API key |
| `OPENAQ_API_KEY` | ❌ | — | OpenAQ key (optional, for higher rate limits) |
| `USE_SAMPLE_DATA` | ❌ | `false` | Set `true` to always use offline sample data |
| `API_HOST` | ❌ | `0.0.0.0` | FastAPI bind host |
| `API_PORT` | ❌ | `8000` | FastAPI bind port |
| `CHROMA_DB_PATH` | ❌ | `./chroma_db` | ChromaDB persistence directory |
| `API_BASE_URL` | ❌ | `http://localhost:8000` | Streamlit → API base URL |

---

## Agents Reference

| Agent | File | Input | Output |
|---|---|---|---|
| AQI Data Agent | `agents/aqi_agent.py` | city | AQI, pollutants, RAG explanation |
| Health Advisory Agent | `agents/health_agent.py` | city, age_group, conditions, AQIResult | Personalised daily actions |
| Forecasting Agent | `agents/forecast_agent.py` | city | 72h forecast, early warnings |
| Community Action Agent | `agents/community_agent.py` | city, AQIResult | Community/policy actions, awareness post |
| Coordinator | `agents/coordinator.py` | city, age_group, conditions | Merged AirActionResponse |

---

## API Reference

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Liveness probe |
| `GET` | `/aqi/{city}` | Fetch only AQI data (fast) |
| `POST` | `/analyze` | Full multi-agent analysis |
| `POST` | `/chat` | Chat follow-up question |

Full interactive docs at `http://localhost:8000/docs` when running locally.

**POST /analyze request body:**

```json
{
  "city": "Delhi",
  "age_group": "adult",
  "conditions": ["asthma"],
  "session_id": "optional-session-id"
}
```

---

## Disclaimer

> ⚠️ **AirAction provides informational guidance only.**
> The health and medical information provided by this system is for general informational
> purposes and is NOT a substitute for professional medical advice, diagnosis, or treatment.
> Always consult a qualified healthcare professional with any questions regarding a medical
> condition or before making changes to your health routine.
> Air quality data is sourced from third-party APIs and may not reflect real-time conditions
> at your exact location.

---

*Built with ❤️ using IBM Bob · IBM Granite · watsonx.ai · FastAPI · Streamlit · ChromaDB*
