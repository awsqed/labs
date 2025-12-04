# Tailscale Host Routing Setup

Configure host-level routing to access Tailscale subnet routes through a Tailscale Docker container.

## Version Selection

Two versions available based on Tailscale container network mode:

| Version | Network Mode | Use Case |
|---------|-------------|----------|
| **Bridge Mode** | Custom Docker network | Tailscale container isolated on its own bridge network |
| **Host Mode** | `--network=host` | Tailscale container shares host network namespace |

## Bridge Network Mode

**Files:**
- [bridge/tailscale-bridge-routing.sh](bridge/tailscale-bridge-routing.sh)
- [bridge/tailscale-bridge-routing.service](bridge/tailscale-bridge-routing.service)

**Requirements:**
- Tailscale container on dedicated Docker network (e.g., "tailscale")
- Container named "tailscale"
- docker-compose-auto.service running

**How It Works:**
1. Waits for Docker daemon and Tailscale container
2. Retrieves container IP from Docker network
3. Adds host route: `10.0.0.0/8 via <container-ip>`
4. Configures NAT masquerading inside container

**Installation:**
```bash
sudo cp bridge/tailscale-bridge-routing.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/tailscale-bridge-routing.sh
sudo cp bridge/tailscale-bridge-routing.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable tailscale-bridge-routing.service
sudo systemctl start tailscale-bridge-routing.service
```

**Verification:**
```bash
sudo systemctl status tailscale-bridge-routing.service
ip route show | grep 10.0.0.0
docker exec tailscale iptables -t nat -L POSTROUTING -n -v
```

## Host Network Mode

**Files:**
- [host/tailscale-host-routing.sh](host/tailscale-host-routing.sh)
- [host/tailscale-host-routing.service](host/tailscale-host-routing.service)

**Requirements:**
- Tailscale container using `--network=host`
- tailscale0 interface created on host by container

**How It Works:**
1. Waits for tailscale0 interface to appear on host
2. Enables IP forwarding via sysctl
3. Configures nftables raw table rule to bypass ufw-docker blocking

**Installation:**
```bash
sudo cp host/tailscale-host-routing.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/tailscale-host-routing.sh
sudo cp host/tailscale-host-routing.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable tailscale-host-routing.service
sudo systemctl start tailscale-host-routing.service
```

**Verification:**
```bash
sudo systemctl status tailscale-host-routing.service
ip link show tailscale0
sysctl net.ipv4.ip_forward
sudo nft list ruleset | grep tailscale0
```

## Testing Connectivity

From a remote Tailscale client:

```bash
# Test access to advertised subnet
ping -c 3 10.1.2.130

# Test with traceroute
traceroute 10.1.2.130

# Check if subnet router is reachable
ping -c 3 100.103.82.84
```

On the subnet router host:

```bash
# Watch traffic on Tailscale interface
sudo tcpdump -i tailscale0 -n icmp

# Check iptables counters
sudo iptables -L FORWARD -n -v

# Check NAT table
sudo iptables -t nat -L POSTROUTING -n -v
```

## Directory Structure

```
tailscale/
├── bridge/
│   ├── tailscale-bridge-routing.sh
│   └── tailscale-bridge-routing.service
├── host/
│   ├── tailscale-host-routing.sh
│   └── tailscale-host-routing.service
└── README.md
```

## Uninstallation

**Bridge Mode:**
```bash
sudo systemctl stop tailscale-bridge-routing.service
sudo systemctl disable tailscale-bridge-routing.service
sudo rm /etc/systemd/system/tailscale-bridge-routing.service
sudo rm /usr/local/bin/tailscale-bridge-routing.sh
sudo systemctl daemon-reload
```

**Host Mode:**
```bash
sudo systemctl stop tailscale-host-routing.service
sudo systemctl disable tailscale-host-routing.service
sudo rm /etc/systemd/system/tailscale-host-routing.service
sudo rm /usr/local/bin/tailscale-host-routing.sh
sudo systemctl daemon-reload
```

## Architecture Comparison

### Bridge Network Mode
```
Host OS
  ├─ tailscale (Docker network)
  │   └─ tailscale container (10.x.x.x)
  │       └─ tailscale0 interface
  ├─ Host routing table
  │   └─ 10.0.0.0/8 via <container-ip>
  └─ Docker containers on other networks
```

### Host Network Mode
```
Host OS
  ├─ tailscale0 interface (created by container)
  ├─ iptables FORWARD/NAT rules
  └─ Docker containers on bridge networks
```

## Performance Considerations

**Bridge Mode:**
- Extra network hop through container network
- Slightly higher latency
- Better isolation

**Host Mode:**
- Direct access to host network stack
- Lower latency
- Less isolation
- Simpler routing

## Security Considerations

Both versions:
- Enable IP forwarding (security impact on host)
- Configure NAT masquerading (changes source IP)
- Require root privileges

Additional for Host Mode:
- Tailscale has direct access to host network interfaces
- Container can modify host iptables rules
- Less network isolation
