import os
import multiprocessing

bind = f"0.0.0.0:{os.getenv('PORT', '8000')}"  # <-- esto es correcto
workers = 1
threads = 2
timeout = 120
accesslog = "-"
errorlog = "-"
worker_class = "gthread"
