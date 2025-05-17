FROM python:3.12

WORKDIR /app

RUN pip install --no-cache-dir flask==3.1.0 kubernetes==32.0.1 gunicorn==23.0.0
COPY falco_guard.py /app/falco_guard.py

# NOTE: Untested. May switch to Falco Talon anyway.
EXPOSE 2801
CMD ["gunicorn", "-b", "0.0.0.0:2801", "falco_guard:app"]
