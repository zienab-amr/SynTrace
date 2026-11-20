FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 PYTHONUTF8=1 PYTHONDONTWRITEBYTECODE=1

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN useradd --create-home syntrace && chown -R syntrace:syntrace /app
USER syntrace

EXPOSE 8000
CMD ["uvicorn", "ai_service:app", "--host", "0.0.0.0", "--port", "8000"]