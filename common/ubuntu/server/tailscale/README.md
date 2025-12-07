# Tailscale Host Routing

Configure host routing to access Tailscale subnet routes through Docker container.

## Mode Selection

| Mode | Network | Container Network | Requirements |
|------|---------|-------------------|--------------|
| **Bridge** | Custom network | Dedicated bridge | Tailscale container on dedicated Docker network, named "tailscale", docker-compose-auto.service |
| **Host** | `--network=host` | Shared with host | Tailscale container using `--network=host`, tailscale0 interface |

## Bridge Mode

**Files:**
- `bridge/tailscale-bridge-routing.sh`
- `bridge/tailscale-bridge-routing.service`

**Mechanism:**
1. Waits for Docker daemon and Tailscale container
2. Retrieves container IP from Docker network
3. Adds route: `10.0.0.0/8 via <container-ip>`
4. Configures NAT masquerading inside container

**Deployment:**
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

## Host Mode

**Files:**
- `host/tailscale-host-routing.sh`
- `host/tailscale-host-routing.service`

**Mechanism:**
1. Waits for tailscale0 interface
2. Enables IP forwarding
3. Configures nftables to bypass ufw-docker blocking

**Deployment:**
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

## Structure

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

## Security Impact

Both modes:
- Enable IP forwarding
- NAT masquerading (changes source IP)
- Require root privileges

Host mode additional:
- Tailscale accesses host interfaces directly
- Container modifies host iptables
- Reduced network isolation
