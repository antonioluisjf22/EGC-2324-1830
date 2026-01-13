#!/bin/bash
# Build script for Render deployment
# Installs dependencies and collects static files

set -e

echo "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo "Collecting static files..."
cd decide
python manage.py collectstatic --noinput

echo "Running migrations..."
python manage.py migrate --noinput

echo "Creating admin user if not exists..."
python manage.py shell -c "
from django.contrib.auth.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', 'admin123')
    print('Admin user created')
else:
    print('Admin user already exists')
"

echo "Build complete!"
