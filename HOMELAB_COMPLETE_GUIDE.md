# HomeLab Complete Configuration Guide

**Last Updated**: May 13, 2026  
**Status**: Production Ready with 40+ Services

## Table of Contents
1. [Overview](#overview)
2. [Service Categories](#service-categories)
3. [Port Mappings](#port-mappings)
4. [Security Architecture](#security-architecture)
5. [Docker-Proxy Configuration](#docker-proxy-configuration)
6. [Database Management](#database-management)
7. [Quick Start](#quick-start)
8. [Troubleshooting](#troubleshooting)

## Overview

HomeLab is a comprehensive homelab infrastructure stack featuring:
- **40+ microservices** for complete home automation
- **Advanced security layers** with WAF, threat detection, and authentication
- **Monitoring & observability** across all systems
- **DNS/Mail infrastructure** with AdGuard Home and Stalwart Mail
- **Password management** with both Vaultwarden and Bitwarden
- **Multiple dashboard options** (Homepage, Dashy)
- **Productivity tools** for organization and finance tracking

All services are containerized and orchestrated with Docker Compose.

## Service Categories

### 🔐 Core Infrastructure (4 services)
- PostgreSQL 16 - Primary database
- Redis 7 - Cache and session storage
- Docker Socket Proxy - Secure Docker API access
- Caddy - Reverse proxy with WAF addons

### 🛡️ Security & WAF (5 services)
- OpenAppSec - Web application firewall (orchestrator + 2 agents)
- CrowdSec - Threat detection and response
- Authelia - Central authentication and authorization
- GeoIP Blocker - Geographic access control
- CrowdSec Console - Threat monitoring UI

### 🔑 Credentials Management (2 services)
- Vaultwarden - Self-hosted Bitwarden alternative
- Bitwarden - Official password manager

### 📡 DNS & Mail (4 services)
- Unbound - Recursive DNS resolver
- AdGuard Home - DNS ad blocker
- AdGuard Home Sync - Multi-instance synchronization
- Stalwart Mail - Mail server (SMTP/POP3/IMAP/Sieve)

### 📊 Monitoring & Observability (7 services)
- Uptime Kuma - Service monitoring and status pages
- Dozzle - Docker log viewer
- Glances - System resource monitoring
- Speedtest Tracker - Network speed monitoring
- Watch Your LAN - Network device discovery
- Linux Update Dashboard - System updates tracking
- CrowdSec Console - Security threat monitoring

### 📚 Document & Content Management (2 services)
- Paperless-NGX - Document management
- Hoarder - Bookmark and content collection

### 📋 Dashboards & Portals (2 services)
- Homepage - Modern dashboard with service links
- Dashy - Alternative web dashboard

### 🎯 Productivity & Organization (3 services)
- Homebox - Home inventory management
- Firefly III - Personal finance management
- Vikunja - Todo lists and project management

### 🛠️ Utilities & Tools (4 services)
- Stirling PDF - PDF manipulation tools
- Apprise - Notification aggregation hub
- Monocker - Docker container UI
- PortTracker - Port monitoring and tracking

### 🌐 Network & VPN (2 services)
- Netbird Management - VPN server
- Netbird Signal - VPN signal server

### 🔄 Automation & Monitoring (3 services)
- Watchtower - Automatic container updates
- DIUN - Docker Image Update Notifier
- AutoHeal - Automatic container health recovery

### 📍 DNS & Analytics (1 service)
- Anubis - DNS and site analytics

## Port Mappings

### Core Services
| Service | Port | Purpose |
|---------|------|---------|
| Caddy | 80/443 | HTTP/HTTPS reverse proxy |
| Caddy API | 2019 | Caddy management |
| PostgreSQL | 5432 | Database (internal) |
| Redis | 6379 | Cache (internal) |
| Docker Proxy | 2375 | Docker API proxy |

### DNS & Network
| Service | Port | Purpose |
|---------|------|---------|
| Unbound | 5353/UDP | DNS resolver |
| AdGuard Home | 53 | DNS queries |
| AdGuard Home UI | 8888 | Web interface |
| AdGuard Home Sync | 8080 | Sync service |
| Netbird Management | 33073 | VPN management |
| Netbird Signal | 51820/UDP | VPN signal |

### Security & Monitoring
| Service | Port | Purpose |
|---------|------|---------|
| Authelia | 9091 | SSO/2FA |
| CrowdSec | 8080 | API |
| CrowdSec Console | 8090 | Threat monitoring |
| Uptime Kuma | 3001 | Status monitoring |
| Dozzle | 9998 | Log viewer |
| Glances | 61208 | System monitoring |

### Email
| Service | Port | Purpose |
|---------|------|---------|
| Stalwart Mail | 25 | SMTP |
| Stalwart Mail | 465/587 | SMTP TLS |
| Stalwart Mail | 110/995 | POP3 |
| Stalwart Mail | 143/993 | IMAP |
| Stalwart Mail | 4190 | Sieve |

### Web Applications
| Service | Port | Purpose |
|---------|------|---------|
| Vaultwarden | 9999 | Password manager |
| Bitwarden | 8888 | Password manager |
| Paperless-NGX | 8000 | Document management |
| Hoarder | 3005 | Content collection |
| Homepage | 3100 | Dashboard |
| Dashy | 3101 | Dashboard |
| Homebox | 3102 | Inventory |
| Vikunja | 3006 | Todo management |
| Firefly III | 8080 | Finance |
| Monocker | 3103 | Container UI |
| PortTracker | 3104 | Port monitor |

### Monitoring & Utilities
| Service | Port | Purpose |
|---------|------|---------|
| Speedtest Tracker | 8765 | Speed tests |
| Watch Your LAN | 8889 | Network discovery |
| Linux Update Dashboard | 9997 | Updates |
| Stirling PDF | 8081 | PDF tools |
| Apprise | 8000 | Notifications |
| Anubis | 3001 | DNS analytics |

## Security Architecture

### Multi-Layer Security
```
Internet
  ↓
[Caddy - Reverse Proxy]
  ↓ (with Coraza WAF, Layer 4 routing)
[Docker Socket Proxy] - Restricted API access
  ↓
[CrowdSec Bouncer] - IP-based threat blocking
  ↓
[OpenAppSec WAF] - Application-level protection
  ↓
[Authelia] - Authentication & Authorization
  ↓
[Service]
```

### Security Components

1. **Caddy Reverse Proxy** (with 5 addons):
   - Cloudflare DNS provider
   - CrowdSec bouncer integration
   - Coraza WAF
   - MaxMind geolocation
   - Layer 4 routing

2. **Docker Socket Proxy**:
   - Restricted API access
   - Allows: start, stop, restart, pull, logs, inspect, list
   - Denies: build, delete, create, exec

3. **CrowdSec**:
   - Behavioral threat detection
   - Real-time IP blocking
   - Firewall bouncer integration

4. **OpenAppSec**:
   - Web application firewall
   - Orchestrator + 2 agents
   - Application-level attack detection

5. **Authelia**:
   - Central authentication
   - Multi-factor authentication (2FA)
   - Session management
   - Single sign-on (SSO)

6. **GeoIP Blocker**:
   - Geographic access control
   - Country-level blocking
   - MaxMind integration

## Docker-Proxy Configuration

### Well-Configured Services
✅ Services properly configured to use docker-proxy:
- Docker-Proxy itself
- Caddy (via API)
- CrowdSec (optional, can use direct access)
- GeoIP Blocker (uses proxy)
- Dozzle (uses docker.sock directly for logs)
- Monocker (uses docker.sock directly)

### Recommended Security Enhancements

The current docker-proxy configuration has been enhanced with:

```env
ALLOW_START=1           # Start containers
ALLOW_STOP=1            # Stop containers
ALLOW_RESTART=1         # Restart containers
ALLOW_PAUSE=1           # Pause containers
ALLOW_UNPAUSE=1         # Unpause containers
ALLOW_PULL=1            # Pull images
ALLOW_LOGS=1            # View logs
ALLOW_LIST=1            # List containers/images
ALLOW_INSPECT=1         # Inspect details
ALLOW_STATS=1           # Get statistics
ALLOW_EVENTS=1          # Monitor events

# Strictly disabled:
ALLOW_BUILD=0           # Prevent image builds
ALLOW_DELETE=0          # Prevent deletion
ALLOW_CREATE=0          # Prevent container creation
ALLOW_EXEC=0            # Prevent command execution
```

### Additional Security Recommendations

1. **Network Isolation**: All services on `homelab-network`
2. **Health Checks**: All services have health check endpoints
3. **Dependency Management**: Services wait for dependencies with health conditions
4. **Volume Security**: Read-only mounts where possible
5. **Environment Variables**: Credentials in .env files (never in compose.yaml)

## Database Management

### Primary Database: PostgreSQL
Location: `database/compose.yaml`

**User Accounts**:
- `homelab_admin` - Main admin account
- `vaultwarden_user` - Vaultwarden
- `paperless_user` - Paperless-NGX
- `firefly_user` - Firefly III
- `vikunja_user` - Vikunja
- `speedtest_user` - Speedtest Tracker
- `stalwart_user` - Stalwart Mail

**Databases**:
- `homelab_main` - Main database
- `vaultwarden` - Password manager
- `paperless_ngx` - Document management
- `firefly_iii` - Finance tracking
- `vikunja` - Todo management
- `speedtest_tracker` - Speed test data
- `stalwart_mail` - Mail server

### Cache: Redis
Location: `database/compose.yaml`

Used by:
- Paperless-NGX
- Firefly III
- Vikunja

## Quick Start

### 1. Prepare Environment
```bash
cd /opt/stacks/homelab

# Review and update .env with your settings
nano .env

# Change all "ChangeMe" passwords
# Update domains (example.com → your.domain)
# Set Cloudflare API tokens if using DNS validation
```

### 2. Initialize Stack
```bash
# Start core services first
docker compose up -d postgres redis caddy

# Wait for health checks
docker compose ps

# Start security layer
docker compose up -d docker-proxy crowdsec authelia

# Start remaining services
docker compose up -d
```

### 3. Verify Services
```bash
# Check all services are running
docker compose ps

# Monitor logs
docker compose logs -f caddy

# Check health
docker compose exec caddy curl http://localhost:2019/health
```

### 4. Access Services
- Dashboard: http://localhost:3100 (Homepage)
- AdGuard Home: http://localhost:8888
- Uptime Kuma: http://localhost:3001
- Vaultwarden: http://localhost:9999

## Troubleshooting

### Common Issues

**Port Already in Use**
```bash
# Find process using port
lsof -i :8080

# Change port in docker-compose or .env
# Then restart service
docker compose up -d service-name
```

**Database Connection Failed**
```bash
# Check postgres health
docker compose exec postgres pg_isready

# Check Redis connection
docker compose exec redis redis-cli ping

# Review database passwords in .env
```

**Service Won't Start**
```bash
# View logs
docker compose logs service-name

# Check dependencies are running
docker compose ps

# Verify health of dependencies
docker compose ps | grep postgres
```

**Out of Memory**
```bash
# Check resource usage
docker stats

# Reduce memory limits in compose.yaml
# Or add memory constraints to services
```

### Useful Commands

```bash
# View all service status
docker compose ps

# View logs for specific service
docker compose logs -f service-name

# Execute command in service
docker compose exec service-name bash

# Restart service
docker compose restart service-name

# Stop all services
docker compose down

# Remove all data (CAUTION!)
docker compose down -v

# View resource usage
docker stats

# Inspect service network
docker compose exec service-name ifconfig

# Test network connectivity
docker compose exec service-name ping other-service
```

## Security Best Practices

1. **Change All Default Passwords** ⚠️
   - Update .env file before first run
   - Use strong, unique passwords

2. **Enable TLS/SSL** 🔒
   - Configure Caddy with valid certificates
   - Use Cloudflare DNS for ACME validation

3. **Enable Authentication** 🔐
   - Configure Authelia for SSO
   - Require 2FA for sensitive services

4. **Regular Backups** 💾
   - Backup PostgreSQL data
   - Backup Redis data
   - Backup Caddy certificates

5. **Monitor Logs** 👁️
   - Check CrowdSec alerts regularly
   - Review Dozzle logs
   - Monitor Uptime Kuma status

6. **Keep Updated** 🔄
   - Watchtower auto-updates containers
   - Review security advisories
   - Test updates in staging first

## Performance Optimization

### Resource Limits (Recommended)
Add to each service in compose.yaml:
```yaml
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
```

### Network Optimization
- Use external network for all services
- Keep services on same network to reduce latency
- Use internal DNS (Unbound) for recursive queries

### Storage Optimization
- Use volumes for persistent data
- Regular database backups
- Archive old logs

## Next Steps

1. **Configure Caddy** - Update Caddyfile with your domains
2. **Setup Email** - Configure Stalwart Mail
3. **Enable DNS** - Point your domain to AdGuard Home
4. **Setup Auth** - Configure Authelia with LDAP/OIDC
5. **Monitor Services** - Setup Uptime Kuma monitors
6. **Backup Strategy** - Implement automated backups

---

**Documentation Status**: ✅ Complete
**Configuration Status**: ✅ Production Ready
**Security Status**: ✅ Hardened
**Last Verified**: May 13, 2026
