#!/bin/bash
set -e

echo "Waiting for Docker to be ready..."
for i in {1..30}; do
    if docker info >/dev/null 2>&1; then
        echo "Docker is ready"
        break
    fi
    sleep 1
done

echo "Waiting for Tailscale container to start..."
for i in {1..30}; do
    if docker ps --format '{{.Names}}' | grep -q "^tailscale$"; then
        echo "Tailscale container is running"
        break
    fi
    sleep 1
done

TAILSCALE_IP=$(docker inspect tailscale -f "{{.NetworkSettings.Networks.tailscale.IPAddress}}")

if [ -z "$TAILSCALE_IP" ]; then
    echo "ERROR: Could not get Tailscale container IP"
    exit 1
fi

echo "Tailscale container IP: $TAILSCALE_IP"

ip route del 10.0.0.0/8 2>/dev/null || true
ip route add 10.0.0.0/8 via $TAILSCALE_IP
echo "Route added successfully"

echo "Adding container iptables rules..."
docker exec tailscale iptables -t nat -D POSTROUTING -o tailscale0 -j MASQUERADE 2>/dev/null || true
docker exec tailscale iptables -t nat -A POSTROUTING -o tailscale0 -j MASQUERADE

echo "Setup complete!"
ip route show | grep "10.0.0.0/8"
