#!/usr/bin/env bash
set -e

# Esperar a la base de datos si DATABASE_URL está definido
if [ -n "$DATABASE_URL" ]; then
  echo "Esperando a la base de datos..."
  DB_HOST=$(python - <<'PY'
import os, re
url=os.environ.get("DATABASE_URL","")
m=re.match(r'^\w+://[^@]+@([^:/]+)(?::(\d+))?/', url)
print(m.group(1) if m else "localhost")
PY
)
  DB_PORT=$(python - <<'PY'
import os, re
url=os.environ.get("DATABASE_URL","")
m=re.match(r'^\w+://[^@]+@([^:/]+)(?::(\d+))?/', url)
print(m.group(2) if (m and m.group(2)) else "5432")
PY
)
  until pg_isready -h "$DB_HOST" -p "$DB_PORT" >/dev/null 2>&1; do
    echo "  -> DB no lista aún. Reintentando..."
    sleep 2
  done
  echo "Base de datos lista."
fi

# Migraciones y archivos estáticos
echo "Ejecutando migraciones..."
python manage.py migrate --noinput

echo "Recolectando archivos estáticos..."
python manage.py collectstatic --noinput || true

# Crear superusuario si no existe con validaciones mejoradas
echo "Verificando superusuario..."
python manage.py shell <<'PY'
import sys
from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError

User = get_user_model()
email = "admin@alcaldiacordoba.gov.co"
password = "cordoba2025"
username = "admin"  # Añadir username

try:
    # Verificar si ya existe por email o username
    user_exists = User.objects.filter(email=email).exists() or User.objects.filter(username=username).exists()
    
    if user_exists:
        # Buscar por email primero, luego por username
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            user = User.objects.get(username=username)
            
        print(f"✅ Superusuario ya existe: {user.email}")
        print(f"   - Username: {user.username}")
        print(f"   - Email: {user.email}")
        print(f"   - Es staff: {user.is_staff}")
        print(f"   - Es superuser: {user.is_superuser}")
        print(f"   - Está activo: {user.is_active}")
        
        # Asegurar que tenga los permisos correctos
        if not user.is_superuser or not user.is_staff or not user.is_active:
            user.is_superuser = True
            user.is_staff = True
            user.is_active = True
            user.save()
            print("   - Permisos actualizados ✅")
    else:
        # Crear nuevo superusuario con username
        user = User.objects.create_superuser(
            username=username,
            email=email, 
            password=password
        )
        user.is_active = True
        user.save()
        print(f"✅ Superusuario creado:")
        print(f"   - Username: {user.username}")
        print(f"   - Email: {user.email}")
        print(f"   - Es staff: {user.is_staff}")
        print(f"   - Es superuser: {user.is_superuser}")
        print(f"   - Está activo: {user.is_active}")

    # Verificar que la autenticación funciona (Django puede usar email o username)
    from django.contrib.auth import authenticate
    
    # Probar autenticación con email
    auth_user = authenticate(username=email, password=password)
    if auth_user:
        print("✅ Autenticación con email verificada")
    else:
        # Probar autenticación con username
        auth_user = authenticate(username=username, password=password)
        if auth_user:
            print("✅ Autenticación con username verificada")
        else:
            print("❌ Error en la autenticación")
            print("   Intentando actualizar la contraseña...")
            user.set_password(password)
            user.save()
            auth_user = authenticate(username=email, password=password)
            if auth_user:
                print("✅ Contraseña actualizada y autenticación exitosa")
            else:
                print("❌ Fallo total en autenticación")

except Exception as e:
    print(f"❌ Error creando superusuario: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PY

echo "Configuración completada ✅"

# ----------------------
# Gunicorn con configuración directa
# ----------------------
PORT=${PORT:-10000}
echo "Iniciando Gunicorn en puerto $PORT..."

exec gunicorn config.wsgi:application \
    --bind 0.0.0.0:$PORT \
    --workers 1 \
    --threads 4 \
    --timeout 120 \
    --worker-class gthread \
    --access-logfile - \
    --error-logfile -
