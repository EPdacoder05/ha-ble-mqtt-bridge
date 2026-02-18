# Home Assistant BLE-MQTT Bridge for ELK-BLEDOM Lights

A production-grade Python bridge that integrates cheap, ELK-BLEDOM based BLE RGB light strips into Home Assistant via MQTT. This project provides a stable, resilient service that automatically handles the flaky nature of the hardware.

## The Journey: From Hack to Stable Service

This project began as an experiment to see if it was possible to manage and control the light strip in Home Assistant, but since it has no official integration, it then turned to reverse-engineering the communication between the device and the app it belonged to.

1.  **Phase 1: The `gatttool` Hack:** Using the deprecated `gatttool` utility, we intercepted and identified the raw byte commands needed to control the light's power, color, and brightness. An initial script was built around this, but it suffered from extreme instability.

2.  **Phase 2: The `bleak` Refactor:** The script was re-architected from the ground up using `bleak`, a modern, asynchronous Python library. This enabled a persistent connection but revealed a "deep sleep" bug in the controller's firmware where it would become unresponsive after being turned off.

3.  **Phase 3: The "Aggressive Wake-Up":** The final breakthrough was to combine the stability of `bleak` with the brute-force nature of the original hack. The script was engineered with a "software power cycle" that forces a full, aggressive reconnection *only* when turning the light on from an off state, reliably shocking the controller awake.

## Features

* **Stable, Persistent Connection:** Uses `bleak` to maintain a connection, with exponential backoff for reconnection attempts.
* **"Aggressive Wake-Up":** Reliably turns the light on from an `OFF` state by forcing a reconnect.
* **State Reconciliation:** Remembers the last command from Home Assistant and restores it upon reconnection.
* **HA Availability:** Reports `online`/`offline` status to Home Assistant for a seamless UI experience.
* **Secure:** Loads all sensitive information (MAC address, MQTT credentials) from a `secrets.yaml` file.

## How It Works: The Architecture

This bridge works by creating a "translator" that sits between Home Assistant's world of MQTT messages and the light strip's world of Bluetooth commands.

The **MQTT Broker** acts as a central post office. Home Assistant drops off a letter (a JSON command), and the Python script picks it up, translates it, and delivers it to the light strip via Bluetooth.

**Flow of a Command:**
`Home Assistant UI -> MQTT Broker -> Python Script -> Bluetooth Adapter -> Light Strip`

## MQTT Setup

This script requires a running MQTT broker. The script connects to the broker, subscribes to a command topic, and publishes state updates. All MQTT configuration is handled in the `secrets.yaml` file.

Create a `secrets.yaml` file in the same directory as the script with the following format:

```yaml
# Your private credentials and configuration
# This file should be added to .gitignore and NOT committed to your repository.

mqtt_broker: "127.0.0.1" # IP address of your MQTT broker (use 127.0.0.1 if on the same machine)
mqtt_port: 1883
mqtt_username: "your_mqtt_user"
mqtt_password: "your_mqtt_password"

device_mac: "BE:67:00:5B:04:4A" # MAC address of your BLE device
base_topic: "bedframe/light" # The base topic for Home Assistant integration
```

## Docker Deployment

This project includes a production-ready, security-hardened Docker container for easy deployment.

### Building the Docker Image

```bash
docker build -t ha-ble-mqtt-bridge:latest .
```

### Docker Security

The Dockerfile implements multiple security best practices:

- **Multi-stage build**: Separates build dependencies from runtime, reducing image size and attack surface
- **Non-root user**: Application runs as `appuser` (non-root) with no shell and no home directory
- **Minimal base image**: Uses `python:3.11-slim-bookworm` for reduced vulnerabilities
- **Health checks**: Container includes health monitoring
- **No privileged mode**: Uses specific capabilities instead of full privileges

### Running with Docker (Secure BLE Access)

**IMPORTANT**: This container needs Bluetooth access. Do **NOT** use `--privileged` mode.

Instead, use specific device mappings and minimal capabilities:

```bash
docker run --net=host \
           --device /dev/hci0 \
           --cap-add=NET_ADMIN \
           --cap-add=NET_RAW \
           -v $(pwd)/secrets.yaml:/app/secrets.yaml:ro \
           --name ble-mqtt-bridge \
           --restart unless-stopped \
           ha-ble-mqtt-bridge:latest
```

**Security Notes**:
- `--net=host`: Required for BLE communication (container shares host's network namespace)
- `--device /dev/hci0`: Maps the Bluetooth adapter (change `hci0` if you have multiple adapters)
- `--cap-add=NET_ADMIN`: Required for Bluetooth network operations
- `--cap-add=NET_RAW`: Required for raw socket access (BLE uses raw sockets)
- `-v secrets.yaml:ro`: Mounts secrets as **read-only**
- **No `--privileged`**: Never needed! Specific capabilities are sufficient and more secure

### Running with Docker Compose (Recommended)

The included `docker-compose.yml` provides the recommended secure configuration:

```bash
docker-compose up -d
```

The compose file automatically handles:
- Secure BLE device access
- Minimal required capabilities
- Non-root execution
- Automatic container restart

### Verifying Security

Check that the container is running as non-root:

```bash
docker exec ble-mqtt-bridge whoami
# Should output: appuser
```

Check applied capabilities (should only show NET_ADMIN and NET_RAW):

```bash
docker inspect ble-mqtt-bridge | grep -A 20 "CapAdd"
```

## Deployment

This script can be deployed in multiple ways:

1. **Docker (Recommended)**: See the "Docker Deployment" section above for the secure, containerized approach
2. **Systemd Service**: Run as a systemd service on a Linux host (like a Raspberry Pi) for direct hardware access

### Final Project Structure:

```bash
ble-mqtt-bridge/
├── .git/
├── venv/
├── .gitignore
├── ble_mqtt_bridge.py  # The main Python script
├── requirements.txt
├── secrets.yaml        # Your private credentials
├── Dockerfile          # Security-hardened Docker image
├── docker-compose.yml  # Recommended Docker deployment
└── ble-mqtt-bridge.service # The systemd service file
```

## Home Assistant Integration

This bridge creates a standard MQTT Light entity in Home Assistant.

```yaml
# In configuration.yaml
mqtt:
  light:
    - name: "Bedframe LED Light"
      unique_id: "bedframe_led_001"
      schema: json
      state_topic: "bedframe/light/state"
      command_topic: "bedframe/light/set"
      availability_topic: "bedframe/light/availability"
      payload_available: "online"
      payload_not_available: "offline"
      supported_color_modes: ["rgb"]
      brightness: true
      optimistic: false
```

## Device Discovery (for new devices)
To find the MAC address and characteristic handle for a new ELK-BLEDOM device:

Find MAC Address: Use bluetoothctl scan on.

Find Characteristic Handle: Run sudo gatttool -t public -b <DEVICE_MAC> --char-desc. The handle is on the line with the UUID 0000fff3-0000-1000-8000-00805f9b34fb.
