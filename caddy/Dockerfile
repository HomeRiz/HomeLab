FROM caddy:latest-builder AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/hslatman/caddy-crowdsec-bouncer \
    --with github.com/corazawaf/coraza-caddy \
    --with github.com/anujc4/caddy-maxmind-geolocation \
    --with github.com/mholt/caddy-l4

FROM caddy:latest

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
