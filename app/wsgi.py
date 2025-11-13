from app import app

# gunicorn entrypoint: gunicorn -c gunicorn.conf.py wsgi:app