#!/bin/bash
set -e

echo "Waiting for Tailscale interface to be ready..."
for i in {1..30}; do
    if ip link show tailscale0 >/dev/null 2>&1; then
        echo "tailscale0 interface exists"
        break
    fi
    sleep 1
done

if ! ip link show tailscale0 >/dev/null 2>&1; then
    echo "ERROR: tailscale0 interface not found"
    exit 1
fi

TAILSCALE_IP=$(ip -4 addr show tailscale0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -z "$TAILSCALE_IP" ]; then
    echo "ERROR: Could not get tailscale0 IP address"
    exit 1
fi

echo "Tailscale interface IP: $TAILSCALE_IP"

echo "Configuring nftables rule to bypass ufw-docker..."

nft add table ip raw 2>/dev/null || true
nft add chain ip raw PREROUTING { type filter hook prerouting priority raw \; policy accept\; } 2>/dev/null || true
nft delete rule ip raw PREROUTING iifname "tailscale0" accept 2>/dev/null || true
nft insert rule ip raw PREROUTING iifname "tailscale0" accept

echo "Setup complete!"
echo "Tailscale interface: tailscale0 (${TAILSCALE_IP})"
echo "nftables bypass rule: configured"
