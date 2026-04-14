FROM python:3.12-slim AS base

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt

# Pre-download embedding model (must come after pip install so sentence_transformers is available).
# Setting TF env vars here avoids slow TF-detection probes during model load.
ENV TRANSFORMERS_NO_TF=1
ENV USE_TF=0
RUN --mount=type=cache,target=/root/.cache/huggingface \
    python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2'); print('Model cached.')"

COPY . .

# ---------- Test stage ----------
FROM base AS test
RUN pip install --no-cache-dir pytest
RUN pytest -q

# ---------- Runtime stage ----------
FROM base AS runtime
EXPOSE 5000
CMD ["python", "app.py"]