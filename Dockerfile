FROM debian:trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends nftables socat tini util-linux \
 && rm -rf /var/lib/apt/lists/*

COPY rootfs/ /
RUN chmod 755 /usr/local/bin/firewall-start /usr/local/bin/firewall-rules

ARG IMAGE_VERSION=dev
ENV IMAGE_VERSION=$IMAGE_VERSION \
    FIREWALL_CONFIG=/config/network \
    FIREWALL_HEALTH_PORT=9999

VOLUME ["/config"]
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s \
    CMD bash -c 'exec 3<>"/dev/tcp/127.0.0.1/$FIREWALL_HEALTH_PORT"'
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/firewall-start"]
