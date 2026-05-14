# HomeLab Handoff Documentation

## Overview
This document provides a concise reference for every service deployed in **HomeLab** (now using the `homelab-network`). It covers:
- Purpose of each application
- How to access it (port & URL)
- Basic setup steps
- How the services inter‑connect
- Security‑focused components and what they protect
- Productivity / homelab tools
- Which services are safe to expose publicly via the Caddy reverse‑proxy (SSL + FQDN)
- Cloudflare Tunnel (`cloudflared`) and the open‑source alternative `pangolin`

---

## 1. Core Infrastructure
| Service | Container | Port(s) | Access URL (via Caddy) | Setup Highlights |
|--------|-----------|---------|-----------------------|-----------------|
| **PostgreSQL** | `postgres` | 5432 (internal) | N/A (internal) | Default DB created from `.env` variables. Used by most apps for persistent storage. |
| **Redis** | `redis` | 6379 (internal) | N/A (internal) | Simple key‑value store for session caches. |
| **Docker‑Proxy** | `docker-proxy` | 2375 (internal) | N/A (internal) | Restricts Docker API access. All containers that need Docker socket mount this proxy. |
| **Caddy** (reverse proxy) | `caddy` | 80/443 (public) | `https://<FQDN>` | Built with addons: Cloudflare DNS, CrowdSec bouncer, Coraza WAF, MaxMind GeoIP, Layer‑4 routing. Handles TLS termination for all public services. |

---

## 2. Security & Credential Management
| Service | Purpose | Protected Assets | Public Exposure |
|--------|---------|------------------|-----------------|
| **Vaultwarden** | Self‑hosted Bitwarden alternative (password manager) | User credentials, secrets | **Yes** – expose via Caddy (`https://vaultwarden.<domain>`) |
| **Bitwarden** (official) | Full‑featured password manager | User credentials, secrets | **Yes** – expose via Caddy (`https://bitwarden.<domain>`) |
| **Authelia** | SSO / 2FA gateway for all web services | Authentication for every UI (HomePage, Dashy, etc.) | **No** – internal, accessed only by Caddy and other services |
| **CrowdSec** | Behaviour‑based threat detection & IP blocking | All inbound traffic (via Caddy) | **No** – runs internally, provides bans to Caddy via bouncer addon |
| **OpenAppSec** | Application‑level WAF (Coraza) | Web applications behind Caddy | **No** – integrated into Caddy, not directly exposed |
| **GeoIP Blocker** | Country‑level access control | Public services (e.g., admin panels) | **No** – internal, works with Caddy WAF |
| **AdGuard Home** | DNS ad‑blocking & filtering | Network‑wide DNS queries | **No** – internal DNS resolver (optional UI on port 8888, can be exposed if desired) |
| **Unbound** | Recursive DNS resolver (upstream for AdGuard) | DNS resolution for the LAN | **No** – internal DNS server |

---

## 3. DNS & Mail Infrastructure
| Service | Purpose | Port(s) | Public URL |
|--------|---------|---------|------------|
| **Stalwart Mail** | Full‑featured mail server (SMTP/IMAP/POP3) | 25, 465, 587, 110, 995, 143, 993, 4190 | `mail.<domain>` (exposed via Cloudflare tunnel) |
| **AdGuard Home** | DNS filtering & UI | 53/UDP/TCP, 8888 (UI) | `http://adguard.<domain>` (optional) |
| **Unbound** | Recursive DNS resolver | 5353 (UDP/TCP) | N/A (internal) |

---

## 4. Monitoring & Observability
| Service | Purpose | Port | Public? |
|--------|---------|------|----------|
| **Uptime Kuma** | Service health dashboard | 3001 | **Yes** – `https://uptime.<domain>` |
| **Dozzle** | Real‑time Docker log viewer | 9998 | **Yes** – `https://logs.<domain>` |
| **Glances** | System resource monitor | 61208 | **Yes** – `https://glances.<domain>` |
| **Speedtest Tracker** | Internet speed monitoring | 8765 | **Yes** – `https://speedtest.<domain>` |
| **Watch‑Your‑LAN** | Network device discovery | 8889 | **Yes** – `https://lan.<domain>` |
| **Linux Update Dashboard** | OS package update overview | 9997 | **Yes** – `https://updates.<domain>` |
| **CrowdSec Console** | Threat‑monitor UI | 8090 | **Yes** – `https://sec.<domain>` |

---

## 5. Document & Content Management
| Service | Purpose | Port | Public? |
|--------|---------|------|----------|
| **Paperless‑NGX** | Scan, store, search documents (OCR) | 8000 | **Yes** – `https://docs.<domain>` |
| **Hoarder** | Bookmark & web‑content collection | 3005 | **Yes** – `https://hoarder.<domain>` |

---

## 6. Dashboards / Portals
| Service | Purpose | Port | Public? |
|--------|---------|------|----------|
| **Homepage** | Modern start‑page with service tiles | 3100 | **Yes** – `https://home.<domain>` |
| **Dashy** | Alternative web dashboard | 3101 | **Yes** – `https://dash.<domain>` |
| **Homebox** | Home inventory management | 3102 | **Yes** – `https://inventory.<domain>` |

---

## 7. Productivity & Homelab Tools
| Service | Purpose | Port | Public? |
|--------|---------|------|----------|
| **Vikunja** | Todo & project management | 3006 | **Yes** – `https://tasks.<domain>` |
| **Firefly III** | Personal finance tracking | 8080 | **Yes** – `https://finance.<domain>` |
| **Stirling‑PDF** | PDF manipulation (merge, split, OCR) | 8081 | **Yes** – `https://pdf.<domain>` |
| **Apprise** | Notification aggregation (Discord, Slack, etc.) | 8000 | **No** – internal service used by other apps |
| **Monocker** | UI for Docker container management | 3103 | **Yes** – `https://docker.<domain>` |
| **PortTracker** | Port usage monitoring | 3104 | **Yes** – `https://ports.<domain>` |
| **Pangolin** | Open‑source tunnel alternative (self‑hosted) | 8443 | **Yes** – `https://pangolin.<domain>` — *directory present, add to compose.yaml to activate* |
| **Cloudflared** | Cloudflare Tunnel client | 5000 | **Yes** – `https://tunnel.<domain>` — *directory present, add to compose.yaml to activate* |

---

## 8. Network / VPN
| Service | Purpose | Port | Public? |
|--------|---------|------|----------|
| **Netbird Management** | VPN management UI | 33073 | **Yes** – `https://vpn.<domain>` |
| **Netbird Signal** | VPN signaling (UDP) | 51820/UDP | **No** – internal traffic only |

---

## 9. Automation & Maintenance
| Service | Purpose | Port | Public? |
|--------|---------|------|----------|
| **Watchtower** | Automatic container image updates | N/A (runs in background) | **No** |
| **DIUN** | Docker Image Update Notifier | 6969 | **No** |
| **AutoHeal** | Restarts unhealthy containers | N/A | **No** |

---

## 10. How Everything Works Together
1. **Caddy** sits at the edge, terminating TLS (via Let's Encrypt or your own certificates). It forwards traffic to internal services based on hostnames defined in its `Caddyfile`.
2. **Security stack** – Traffic first passes through Caddy’s Coraza WAF, then the CrowdSec bouncer, and finally the GeoIP blocker. This layered approach blocks malicious IPs, filters by geography, and applies OWASP‑style rules.
3. **Authentication** – Authelia protects every UI. Caddy forwards authentication requests to Authelia; once a user is logged in, a JWT cookie grants access to downstream services.
4. **Data services** – PostgreSQL and Redis provide persistent storage for all apps. They are only reachable from the `homelab-network`.
5. **Monitoring** – Uptime Kuma, Dozzle, Glances, etc., poll the health endpoints of each container. Alerts can be routed via Apprise to your preferred notification channels.
6. **Public exposure** – Only services that need external access are exposed through Caddy (e.g., Vaultwarden, Paperless‑NGX, Homebox, etc.). All other services remain internal.
7. **Tunnel** – `cloudflared` creates a secure outbound tunnel to Cloudflare, allowing you to expose Caddy (and thus all public services) without opening inbound ports. `pangolin` can be used as a self‑hosted alternative if you prefer not to rely on Cloudflare.

---

## 11. Cloudflare Tunnel (`cloudflared`)
### What it does
- Opens an outbound TLS tunnel from your homelab to Cloudflare’s edge network.
- Cloudflare then proxies traffic to your Caddy instance, handling DNS, TLS, and DDoS protection.
### Setup Steps
1. **Create a Tunnel** in the Cloudflare dashboard → *Zero Trust* → *Tunnels* → *Create Tunnel*.
2. **Download the token** and place it in `cloudflared/.env` as `CLOUDFLARED_TUNNEL_TOKEN`.
3. **Configure `config.yaml`** (already provided) – map hostnames to internal services.
4. **Start the service** – `docker compose up -d cloudflared`.
5. **Update DNS** – Cloudflare will automatically create CNAME records for the hostnames you defined.

---

## 12. Pangolin – Open‑Source Tunnel Alternative
### Why use Pangolin?
- No vendor lock‑in; runs entirely on your own infrastructure.
- Supports mutual TLS authentication and custom routing.
### Basic Setup
1. **Generate TLS certificates** for the server (`pangolin` container) and clients.
2. **Configure `pangolin/.env`** with server address, TLS settings, and routing variables.
3. **Define service routes** (e.g., `PANGOLIN_SERVICE_VAULTWARDEN`) to point to internal containers.
4. **Run the container** – `docker compose up -d pangolin`.
5. **Expose the server port** (8443) via your router or a Cloudflare Tunnel if you still want external access.
6. **Clients** connect using the generated token (`PANGOLIN_AUTH_TOKEN`).

### When to choose Pangolin over Cloudflare
- You need full control over the tunnel endpoint.
- You prefer self‑hosted solutions for privacy or compliance.
- You want to avoid Cloudflare rate‑limits or paid plans.

---

## 13. Public‑Facing Services (Recommended FQDNs)
| Service | Suggested FQDN | Reason for Exposure |
|---------|----------------|----------------------|
| Vaultwarden | `vaultwarden.<domain>` | Password manager – needs external access for browsers & mobile apps |
| Bitwarden | `bitwarden.<domain>` | Official password manager |
| Paperless‑NGX | `docs.<domain>` | Document storage for remote access |
| Homebox | `inventory.<domain>` | Home inventory – useful on mobile |
| Vikunja | `tasks.<domain>` | Todo & project management |
| Firefly III | `finance.<domain>` | Personal finance tracking |
| AdGuard Home UI | `dns.<domain>` (optional) | DNS admin UI |
| Stalwart Mail (SMTP) | `mail.<domain>` | Email service – expose via Cloudflare tunnel for secure inbound mail |
| Monitoring dashboards (Uptime, Glances, etc.) | `monitor.<domain>` | Quick status overview |
| Cloudflared / Pangolin endpoint | `tunnel.<domain>` or `pangolin.<domain>` | Tunnel entry point |

---

## 14. Quick Start Checklist
1. **Edit `.env`** – replace all placeholder passwords, set your domain (`CLOUDFLARE_DOMAIN`), and configure Cloudflare tunnel token.
2. **Create DNS records** – either let Cloudflare auto‑create via the tunnel or add manual CNAMEs for the FQDNs above.
3. **Start core services**:
   ```bash
   cd /opt/stacks/homelab
   docker compose up -d postgres redis docker-proxy caddy
   ```
4. **Start security stack**:
   ```bash
   docker compose up -d crowdsec authelia openappsec geoip-blocker
   ```
5. **Deploy remaining apps** (monitoring, productivity, etc.):
   ```bash
   docker compose up -d
   ```
6. **Launch tunnel**:
   ```bash
   docker compose up -d cloudflared   # or pangolin if you prefer
   ```
7. **Verify** – Open a browser to `https://<your‑domain>` and ensure the Homepage loads, then navigate to individual services.
8. **Backup** – Periodically dump PostgreSQL and copy the `config/` directories for Caddy, AdGuard, and other stateful services.

---

## 15. Maintenance Tips
- **Update images** – Watchtower will automatically pull newer versions.
- **Health checks** – All containers expose `/health` endpoints; monitor them via Uptime Kuma.
- **Logs** – Dozzle aggregates container logs; set a retention policy.
- **Security** – Regularly review CrowdSec alerts and update WAF rules in Caddy.
- **Certificates** – Let Caddy auto‑renew Let’s Encrypt certificates, or import your own via the `Caddyfile`.

---

*Prepared for the homelab owner on **May 13, 2026**. All services are now using the `homelab-network` and ready for production.*
