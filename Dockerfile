# ================================
# Stage 1: Builder
# ================================
FROM python:3.11-slim-bookworm@sha256:04cd27899595a99dfe77709d96f08876bf2ee99139ee2f0fe9ac948005034e5b AS builder

WORKDIR /build

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ================================
# Stage 2: Runtime
# ================================
FROM python:3.11-slim-bookworm@sha256:04cd27899595a99dfe77709d96f08876bf2ee99139ee2f0fe9ac948005034e5b

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

# Healthcheck: Verify the BLE MQTT bridge process is running
# Uses /proc filesystem to check if the main process (PID 1) is running
# In a container, the main process is PID 1
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD test -f /proc/1/cmdline && grep -q ble_mqtt_bridge.py /proc/1/cmdline || exit 1

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
