#!/bin/bash
set -e

echo "=== INICIANDO ENTRYPOINT ==="
echo "PORT variable: ${PORT:-no definido}"

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

# Ejecutar migraciones
echo "Ejecutando migraciones..."
python manage.py migrate --noinput

# 🚀 CREAR/VERIFICAR SUPERUSER DIRECTAMENTE
echo "Creando/verificando usuario administrador..."
python manage.py shell << 'EOF'
import os
from apps.authentication.models import CustomUser

email = 'admin@alcaldiacordoba.gov.co'
password = os.environ.get('ADMIN_PASSWORD', 'cordoba2025')

print(f"Verificando usuario: {email}")

try:
    user = CustomUser.objects.get(email=email)
    print(f"✅ Usuario {email} ya existe")
    
    # Asegurar que tenga todos los permisos
    updated = False
    if not user.is_superuser:
        user.is_superuser = True
        updated = True
    if not user.is_staff:
        user.is_staff = True  
        updated = True
    if not user.is_active:
        user.is_active = True
        updated = True
    
    if updated:
        user.save()
        print("🔧 Permisos actualizados")
    else:
        print("✅ Permisos ya están correctos")
        
except CustomUser.DoesNotExist:
    print(f"🚀 Creando superuser {email}")
    user = CustomUser.objects.create_user(
        email=email,
        password=password,
        first_name='Administrador',
        last_name='Sistema'
    )
    user.is_superuser = True
    user.is_staff = True
    user.is_active = True
    user.save()
    print(f"✅ Superuser {email} creado exitosamente")

# Verificación final
final_user = CustomUser.objects.get(email=email)
print("📋 Estado final:")
print(f"   Email: {final_user.email}")
print(f"   Superuser: {final_user.is_superuser}")
print(f"   Staff: {final_user.is_staff}")
print(f"   Active: {final_user.is_active}")
EOF

# Recolectar archivos estáticos
echo "Recolectando archivos estáticos..."
python manage.py collectstatic --noinput || true

# Obtener puerto e iniciar Gunicorn
PORT=${PORT:-8000}
echo "=== INICIANDO GUNICORN EN PUERTO $PORT ==="

exec gunicorn config.wsgi:application \
  --bind 0.0.0.0:$PORT \
  --config gunicorn.conf.py \
  --log-level info \
  --access-logfile - \
  --error-logfile -
