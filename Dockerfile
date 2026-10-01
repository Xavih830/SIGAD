FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /backend

# Instalar dependencias del sistema: compiladores, librerías postgres, Tesseract 5 y Poppler
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        libpq-dev \
        tesseract-ocr \
        tesseract-ocr-spa \
        libtesseract-dev \
        poppler-utils && \
    rm -rf /var/lib/apt/lists/*

# Instalar dependencias Python
COPY backend/requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copiar código fuente del backend
COPY backend/ .

# Directorio de uploads con permisos
RUN mkdir -p /app/uploads

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
