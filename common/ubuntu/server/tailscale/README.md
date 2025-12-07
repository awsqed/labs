# Tailscale Host Routing

Configure host routing to access Tailscale subnet routes through Docker container.

## Version Selection

| Version | Network Mode | Container Network | Use Case |
|---------|--------------|-------------------|----------|
| **Bridge** | Custom network | Dedicated bridge | Isolated container on own network |
| **Host** | `--network=host` | Shared with host | Direct host namespace access |

## Bridge Network Mode

**Files:**
- `bridge/tailscale-bridge-routing.sh`
- `bridge/tailscale-bridge-routing.service`

**Requirements:**
- Tailscale container on dedicated Docker network (e.g., "tailscale")
- Container named "tailscale"
- docker-compose-auto.service running

**How It Works:**
1. Waits for Docker daemon and Tailscale container
2. Retrieves container IP from Docker network
3. Adds route: `10.0.0.0/8 via <container-ip>`
4. Configures NAT masquerading in container

**Installation:**
```bash
sudo cp bridge/tailscale-bridge-routing.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/tailscale-bridge-routing.sh
sudo cp bridge/tailscale-bridge-routing.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now tailscale-bridge-routing.service
```

**Verification:**
```bash
sudo systemctl status tailscale-bridge-routing.service
ip route show | grep 10.0.0.0
docker exec tailscale iptables -t nat -L POSTROUTING -n -v
```

## Host Network Mode

**Files:**
- `host/tailscale-host-routing.sh`
- `host/tailscale-host-routing.service`

**Requirements:**
- Tailscale container using `--network=host`
- tailscale0 interface on host

**How It Works:**
1. Waits for tailscale0 interface
2. Enables IP forwarding
3. Configures nftables to bypass ufw-docker blocking

**Installation:**
```bash
sudo cp host/tailscale-host-routing.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/tailscale-host-routing.sh
sudo cp host/tailscale-host-routing.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now tailscale-host-routing.service
```

**Verification:**
```bash
sudo systemctl status tailscale-host-routing.service
ip link show tailscale0
sysctl net.ipv4.ip_forward
sudo nft list ruleset | grep tailscale0
```

## Testing Connectivity

**From remote Tailscale client:**
```bash
ping -c 3 10.1.2.130              # Test subnet
traceroute 10.1.2.130             # Check route
ping -c 3 100.103.82.84           # Test router
```

**On subnet router host:**
```bash
sudo tcpdump -i tailscale0 -n icmp         # Watch traffic
sudo iptables -L FORWARD -n -v             # Check counters
sudo iptables -t nat -L POSTROUTING -n -v  # Check NAT
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

### Bridge Mode
```
Host
├─ tailscale network (Docker)
│   └─ tailscale container (10.x.x.x)
│       └─ tailscale0 interface
├─ Route: 10.0.0.0/8 via <container-ip>
└─ Other Docker containers
```

### Host Mode
```
Host
├─ tailscale0 interface (created by container)
├─ iptables FORWARD/NAT rules
└─ Docker containers on bridges
```

## Performance & Security

| Aspect | Bridge Mode | Host Mode |
|--------|-------------|-----------|
| **Latency** | Higher (extra hop) | Lower (direct) |
| **Isolation** | Better | Less |
| **Complexity** | More complex | Simpler routing |
| **Host Access** | Limited | Full network stack |

**Security Impact (Both):**
- Enables IP forwarding
- NAT masquerading (changes source IP)
- Requires root privileges

**Additional (Host Mode):**
- Tailscale accesses host interfaces directly
- Container modifies host iptables
- Reduced network isolation
