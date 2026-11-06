FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

WORKDIR /srv/chatbot
COPY requirements.txt .
# pytest dkk. ikut terpasang dari requirements.txt; ukurannya kecil dan tidak dipakai saat runtime.
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY data ./data

# Cache indeks KB ditulis ke runtime/; jalankan sebagai pengguna biasa.
RUN useradd --create-home --uid 10001 chatbot && mkdir runtime && chown -R chatbot runtime
USER chatbot

# Staging/produksi: token demo mati, dan semua rahasia datang dari environment platform.
ENV MOBILE_DEMO_TOKENS=false PORT=8000
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s \
  CMD python -c "import os,urllib.request;urllib.request.urlopen(f'http://127.0.0.1:{os.environ[\"PORT\"]}/health',timeout=4)"

CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --proxy-headers --forwarded-allow-ips='*'"]
