# ════════════════════════════════════════════════════════════════════
#  ChatBantu — Docker image for Render deployment
#  Pure Bantu + Sua + SQLite, no Node.js, no Python, no other runtime.
# ════════════════════════════════════════════════════════════════════
FROM ubuntu:22.04

# Avoid tzdata / interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Africa/Dar_es_Salaam

# Install runtime libraries the Bantu binary needs:
#   - libsqlite3-0     → libsqlite3.so.0  (SQLite)
#   - libcurl*-gnutls  → libcurl-gnutls.so.4  (Bantu's HTTP client)
#   - ca-certificates  → TLS roots
#   - sqlite3          → optional CLI for DB inspection
# The package that provides libcurl-gnutls.so.4 is named differently
# across Ubuntu releases — install whichever apt can find.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libsqlite3-0 \
        ca-certificates \
        sqlite3 \
    && ( apt-get install -y --no-install-recommends libcurl3-gnutls \
         || apt-get install -y --no-install-recommends libcurl3t64-gnutls \
         || apt-get install -y --no-install-recommends libcurl4 \
       ) \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the Bantu binary (Linux x86_64, prebuilt for Ubuntu 22.04)
COPY bantu /usr/local/bin/bantu
RUN chmod +x /usr/local/bin/bantu

# Copy the application (Bantu backend + static frontend)
COPY server.b /app/server.b
COPY public/  /app/public/

# Render mounts a persistent volume at /data for SQLite.
# Create it with world-writable perms so the bantu process can write
# regardless of which UID Render runs the container as.
RUN mkdir -p /data && chmod 777 /data

# Default port (Render injects $PORT)
ENV PORT=8080
EXPOSE 8080

# Pre-flight check: print glibc/libstdc++ requirements and verify the
# binary can actually start. If this fails, Render will show the error
# in the deploy logs instead of a cryptic runtime crash.
RUN echo "=== Bantu binary pre-flight ===" \
    && ldd /usr/local/bin/bantu \
    && /usr/local/bin/bantu --version

# Run the Bantu interpreter on server.b.
# Bantu's sua.server.listen($PORT) blocks forever, accepting HTTP.
CMD ["bantu", "run", "server.b"]
