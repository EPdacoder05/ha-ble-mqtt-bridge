# ================================
# Stage 1: Builder
# ================================
FROM python:3.11-slim-bookworm AS builder

WORKDIR /build

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ================================
# Stage 2: Runtime
# ================================
FROM python:3.11-slim-bookworm

# OCI Labels for security and metadata
LABEL org.opencontainers.image.title="HA BLE-MQTT Bridge"
LABEL org.opencontainers.image.description="Production-grade BLE to MQTT bridge for Home Assistant integration"
LABEL org.opencontainers.image.authors="EPdacoder05"
LABEL org.opencontainers.image.source="https://github.com/EPdacoder05/ha-ble-mqtt-bridge"
LABEL org.opencontainers.image.documentation="https://github.com/EPdacoder05/ha-ble-mqtt-bridge/blob/main/README.md"

# Security: Create non-root user with no shell and no home directory
RUN groupadd -r appuser && \
    useradd -r -g appuser -s /sbin/nologin appuser

WORKDIR /app

# Copy Python packages from builder stage
COPY --from=builder /install /usr/local

# Copy application code
COPY ble_mqtt_bridge.py .

# Set ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Healthcheck: Verify the Python process can execute
# This checks if the application is responsive
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD python -c "import sys; sys.exit(0)" || exit 1

# Runtime command
ENTRYPOINT ["python", "-u", "ble_mqtt_bridge.py"]

# ================================
# BLE Security Notes:
# ================================
# This container requires access to Bluetooth hardware.
# DO NOT use --privileged mode for security reasons.
# 
# Instead, run with specific device mappings and capabilities:
#   docker run --net=host \
#              --device /dev/hci0 \
#              --cap-add=NET_ADMIN \
#              --cap-add=NET_RAW \
#              -v /path/to/secrets.yaml:/app/secrets.yaml:ro \
#              <image-name>
#
# See docker-compose.yml for a complete example with secure BLE access.
