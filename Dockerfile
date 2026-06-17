# ════════════════════════════════════════════════════════════════════
#  ChatBantu — Docker image for Render deployment
#  Pure Bantu + Sua + SQLite, no Node.js, no Python, no other runtime.
# ════════════════════════════════════════════════════════════════════
FROM ubuntu:22.04

# Avoid tzdata / interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Africa/Dar_es_Salaam

# Install only what the Bantu binary needs:
#   - libsqlite3-0  → SQLite runtime
#   - libcurl-gnutls4 → HTTP client runtime (Bantu binary depends on this)
#   - ca-certificates → for HTTPS
#   - sqlite3 → optional, for manual DB inspection
RUN apt-get update && apt-get install -y --no-install-recommends \
        libsqlite3-0 \
        libcurl-gnutls4 \
        ca-certificates \
        sqlite3 \
        && rm -rf /var/lib/apt/lists/*

# Working directory inside the container
WORKDIR /app

# Copy the Bantu binary (Linux x86_64, built in CI / locally)
COPY bantu /usr/local/bin/bantu
RUN chmod +x /usr/local/bin/bantu

# Copy the application (Bantu backend + static frontend)
COPY server.b     /app/server.b
COPY public/      /app/public/

# Render mounts a persistent volume at /data for SQLite
RUN mkdir -p /data

# Default port (Render injects $PORT)
ENV PORT=8080
EXPOSE 8080

# Run the Bantu interpreter on server.b
# Bantu's sua.server.listen($PORT) blocks forever, accepting HTTP.
CMD ["bantu", "run", "server.b"]
