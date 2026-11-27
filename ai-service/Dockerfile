FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 PYTHONUTF8=1 PYTHONDONTWRITEBYTECODE=1

# DejaVu Sans: the meeting requirements PDF (English with Arabic names and days)
RUN apt-get update && apt-get install -y --no-install-recommends fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN useradd --create-home syntrace && chown -R syntrace:syntrace /app
USER syntrace

EXPOSE 8000
CMD ["uvicorn", "syntrace_ai.api.ai_service:app", "--host", "0.0.0.0", "--port", "8000"]
