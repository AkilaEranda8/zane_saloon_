FROM python:3.11-slim

WORKDIR /app

# Install dependencies first (layer cache)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy bot source
COPY . .

EXPOSE 8000

# Preload the model at startup, then serve
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
