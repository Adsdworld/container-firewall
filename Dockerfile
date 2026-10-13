FROM debian:trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl nftables socat tini util-linux \
 && rm -rf /var/lib/apt/lists/*

COPY rootfs/ /
RUN chmod 755 /usr/local/bin/firewall-start /usr/local/bin/firewall-rules /usr/local/bin/firewall-check /usr/local/bin/firewall-health

ARG IMAGE_VERSION=dev
ENV IMAGE_VERSION=$IMAGE_VERSION

VOLUME ["/config"]
HEALTHCHECK --interval=10s --timeout=6s --start-period=10s --start-interval=1s --retries=1 \
    CMD curl -fsS http://127.0.0.1/ | grep -qx Ok
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/firewall-start"]
