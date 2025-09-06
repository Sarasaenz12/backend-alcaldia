#!/bin/bash
set -e

echo "=== INICIANDO ENTRYPOINT ==="
echo "Argumentos recibidos: $@"
echo "PORT variable: ${PORT:-no definido}"
echo "Usuario actual: $(whoami)"

# Esperar a la base de datos si DATABASE_URL está definido 
if [ -n "$DATABASE_URL" ]; then 
  echo "Esperando a la base de datos..."

  DB_HOST=$(python3 - <<'PY'
import os, re
url = os.environ.get("DATABASE_URL", "")
m = re.match(r'^\w+://[^@]+@([^:/]+)(?::(\d+))?/', url)
print(m.group(1) if m else "")
PY
)

  DB_PORT=$(python3 - <<'PY'
import os, re
url = os.environ.get("DATABASE_URL", "")
m = re.match(r'^\w+://[^@]+@([^:/]+)(?::(\d+))?/', url)
print(m.group(2) if (m and m.group(2)) else "5432")
PY
)

  if [ -n "$DB_HOST" ]; then
    until pg_isready -h "$DB_HOST" -p "$DB_PORT" >/dev/null 2>&1; do
      echo "  -> DB no lista aún. Reintentando..."
      sleep 2
    done
    echo "Base de datos lista."
  fi
fi 

# Migraciones y archivos estáticos 
echo "Ejecutando migraciones..."
python manage.py migrate --noinput

echo "Recolectando archivos estáticos..."
python manage.py collectstatic --noinput || true

# Obtener el puerto de la variable de entorno
PORT=${PORT:-8000}
echo "Puerto configurado: $PORT"

echo "=== INICIANDO GUNICORN ==="
echo "Comando a ejecutar: gunicorn config.wsgi:application --bind 0.0.0.0:$PORT --config gunicorn.conf.py"

# Verificar que el archivo wsgi existe
if [ ! -f "config/wsgi.py" ]; then
  echo "ERROR: No se encuentra config/wsgi.py"
  ls -la config/
  exit 1
fi

# Verificar que gunicorn está instalado
which gunicorn || (echo "ERROR: gunicorn no está instalado" && exit 1)

# Ejecutar Gunicorn directamente
exec gunicorn config.wsgi:application \
  --bind 0.0.0.0:$PORT \
  --config gunicorn.conf.py \
  --log-level info \
  --access-logfile - \
  --error-logfile -
