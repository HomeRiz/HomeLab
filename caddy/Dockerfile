FROM caddy:2.11.7-builder AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/hslatman/caddy-crowdsec-bouncer \
    --with github.com/corazawaf/coraza-caddy \
    --with github.com/anujc4/caddy-maxmind-geolocation \
    --with github.com/mholt/caddy-l4

FROM caddy:2.11.7

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
