# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization
#
# Dockerfile multi-stage production-ready:
#   - Stage `builder`: cài dependencies
#   - Stage `runtime`: base slim, non-root user, healthcheck, dynamic PORT
# ═══════════════════════════════════════════════════════════════════

# Stage 1: Builder
FROM python:3.11-slim AS builder

WORKDIR /app

# COPY requirements.txt và cài đặt trước để tận dụng layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy thư viện đã cài từ builder stage sang /usr/local
COPY --from=builder /install /usr/local

# Tạo user thường non-root
RUN useradd --create-home --uid 10001 appuser

# Copy source code sau cùng
COPY app ./app
COPY utils ./utils

# Chạy bằng user thường thay vì root
USER appuser

EXPOSE 8000

# Định kỳ kiểm tra sức khỏe container bằng endpoint /health
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health').read()" || exit 1

# Nhận port động từ biến môi trường PORT của platform (mặc định 8000)
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
