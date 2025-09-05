# Imagen base ligera de Python
FROM python:3.11-slim

LABEL maintainer="estra"
LABEL description="Backend del Sistema de Indicadores - Alcaldía"

# Variables de entorno
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=config.settings

WORKDIR /app

# Dependencias del sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    postgresql-client \
    libpq-dev \
    libmagic1 \
    && rm -rf /var/lib/apt/lists/*

# Instalar dependencias de Python
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && pip install --no-cache-dir -r requirements.txt

# Copiar el código fuente
COPY . .

# Crear directorios para estáticos y media
RUN mkdir -p /app/staticfiles /app/media

# Copiar entrypoint y gunicorn config, dar permisos
COPY entrypoint.sh /app/entrypoint.sh
COPY gunicorn.conf.py /app/gunicorn.conf.py
RUN chmod +x /app/entrypoint.sh

# Crear usuario no-root y asignar permisos
RUN useradd --create-home --shell /bin/bash app && \
    chown -R app:app /app
USER app

# Puerto interno del contenedor
EXPOSE 8000

# Ejecutar entrypoint que manejará $PORT de Render
ENTRYPOINT ["/app/entrypoint.sh"]
