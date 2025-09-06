import os

# No definir bind aquí ya que se pasa por línea de comandos
workers = 1
threads = 4
timeout = 120
worker_class = "gthread"

# Logging
loglevel = "info"
accesslog = "-"
errorlog = "-"

# Optimizaciones básicas
preload_app = True
max_requests = 1000
max_requests_jitter = 100
