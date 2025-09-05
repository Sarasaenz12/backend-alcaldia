import os

# Render maneja el puerto automáticamente
# No necesitamos especificar bind aquí ya que lo hacemos en entrypoint.sh
workers = 1
threads = 4
timeout = 120
worker_class = "gthread"
accesslog = "-"
errorlog = "-"
preload_app = True
max_requests = 1000
max_requests_jitter = 100
