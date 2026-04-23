# Backend image dla symulacji public deploy (nie dla prod — prod na hostingu).
# Celem jest odtworzenie warunków: production env, brak docs, stricht guards.
FROM python:3.14-slim

WORKDIR /app

# System deps: libheif dla Pillow+HEIF (Pixel photos), mariadb-client dla pymysql
RUN apt-get update && apt-get install -y --no-install-recommends \
    libheif1 \
    libheif-plugin-libde265 \
    default-libmysqlclient-dev \
    pkg-config \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# CPU-only torch wheel (GPU niepotrzebne w symulacji)
ENV PIP_INDEX_URL=https://download.pytorch.org/whl/cpu
RUN pip install --no-cache-dir torch==2.11.0

ENV PIP_INDEX_URL=https://pypi.org/simple
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt pillow-heif

COPY app/ /app/app/

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
