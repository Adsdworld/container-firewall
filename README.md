# container-firewall

A container that restricts the network of another container.

The other container joins its network namespace (`network_mode:
service:container-firewall` in Compose, `--network container:<name>` with
`docker run`, or the same pod in Kubernetes). It then has no network of its own:
all its traffic goes through the rules this container applied, and without
`NET_ADMIN` it cannot change them.

Built first for [agent](https://github.com/Adsdworld/agent), usable in front of
any container.

## Contract

- It applies the rules of `/config/network`, mounted read-only, and drops
  everything else.
- Once the rules are applied, it gives up root and every capability; a single
  unprivileged process stays, answering a health check on a local port.
- The container behind it can check that port at start: it only sees it from
  inside this container's network, so it can refuse to start without the
  firewall.
- It depends on nothing but the ability of the container engine to share a
  network namespace, which Docker, Podman, containerd and Kubernetes all have.

## Rules

```
ipv4 on
ipv6 off
internet on
allow 192.168.1.2 tcp 8888,30000,30060
```

Each line is a switch or a rule; the defaults are `ipv4 on`, `ipv6 off`,
`internet on`, and no `allow` line.

- `ipv4 on|off`, `ipv6 on|off`: circuit breakers. `off` drops all traffic of
  that protocol, whatever the other lines say.
- `internet on`: any address outside the private ranges is reachable, and so
  are the DNS servers the container uses.
- `internet off`: no address outside the private ranges is reachable, and no
  DNS server either, unless an `allow` line names it. No exception for any
  provider.
- `allow <address or range> <tcp|udp> <ports>`: on the private ranges, only
  these are reachable, whether the internet is on or off.
- Everything else is dropped.

The private ranges are `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, and for
IPv6 `fc00::/7`. `100.64.0.0/10` (carrier-grade NAT) and the link-local ranges
(`169.254.0.0/16`, `fe80::/10`, cloud metadata services) are not private: they
are only reachable through an `allow` line.

The firewall only sees direct connections: an allowed host that reaches the
internet itself (a proxy, an MCP server fetching web pages) is a way out it
cannot close.

## Open questions

- Docker's embedded DNS (`127.0.0.11`) answers on loopback, so these rules do
  not see it: with `internet off`, should it be blocked too?

## License

Apache-2.0
