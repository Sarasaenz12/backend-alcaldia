#!/bin/bash

# Aplicar migraciones
python manage.py makemigrations
python manage.py migrate

# Crear/actualizar superuser con role correcto
python -c "
import os
import django
from django.conf import settings

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from apps.authentication.models import CustomUser

email = 'admin@alcaldiacordoba.gov.co'
password = 'cordoba2025'
first_name = 'Administrador'
last_name = 'Sistema'

try:
    user = CustomUser.objects.get(email=email)
    print(f'Usuario {email} ya existe.')
    # ASEGURAR QUE TENGA LOS PERMISOS CORRECTOS
    user.is_superuser = True
    user.is_staff = True
    user.is_active = True
    
    # VERIFICAR SI EL MODELO TIENE CAMPO 'role' Y ESTABLECERLO
    if hasattr(user, 'role'):
        user.role = 'admin'
        print('Campo role establecido como admin')
    else:
        print('El modelo no tiene campo role - verificar serializer/vista')
    
    user.save()
    print('Permisos de admin actualizados correctamente.')
    print(f'is_superuser: {user.is_superuser}')
    print(f'is_staff: {user.is_staff}')
    if hasattr(user, 'role'):
        print(f'role: {user.role}')
        
except CustomUser.DoesNotExist:
    user = CustomUser.objects.create_user(
        email=email,
        password=password,
        first_name=first_name,
        last_name=last_name
    )
    user.is_superuser = True
    user.is_staff = True
    user.is_active = True
    
    # ESTABLECER ROLE SI EXISTE EL CAMPO
    if hasattr(user, 'role'):
        user.role = 'admin'
        print('Campo role establecido como admin para nuevo usuario')
    
    user.save()
    print(f'Superuser {email} creado exitosamente.')

print('Script de creación de admin completado.')
"

# Recopilar archivos estáticos
python manage.py collectstatic --noinput

# Iniciar el servidor en el puerto que Render proporciona
python manage.py runserver 0.0.0.0:$PORT
