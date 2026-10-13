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

- It applies the rules of `/config/config`, mounted read-only, and drops
  everything else.
- Once the rules are applied, two processes stay:
  - a checker, root with no capability but `NET_ADMIN` and no port open:
    every 10 seconds it compares the rules in force with the ones it applied,
    applies them again when they differ and says so in its output;
  - the health check, as `nobody` with no capability but binding port 80:
    `GET http://127.0.0.1/` answers `Ok` only when the last check passed less
    than 30 seconds ago, `503 Unverified` otherwise. It reads a state, it
    cannot trigger anything.
- The container behind it can check that address at start: it only sees it
  from inside this container's network, so it can refuse to start without the
  firewall.
- It depends on nothing but the ability of the container engine to share a
  network namespace, which Docker, Podman, containerd and Kubernetes all have.

## Run

```yaml
services:
  firewall:
    image: ghcr.io/adsdworld/container-firewall:latest
    cap_add: [NET_ADMIN]
    volumes:
      - ./firewall/config:/config:ro
  protected:
    image: <the container to protect>
    network_mode: service:firewall
    depends_on:
      firewall:
        condition: service_healthy
        restart: true
```

- The rules are read once, when the container starts: to change them, edit
  `/config/config` and restart the firewall, then the protected container
  (Compose does both with `restart: true`).
- Ports the protected container must publish are published on the firewall,
  since it owns the network. Port 80 of `127.0.0.1` is taken by the health
  check.
- `docker logs firewall` shows the rules in force.

### Failing closed

- First thing at start, everything but loopback is dropped.
- An invalid line in the rules, or a missing `NET_ADMIN`, stops the container
  with that lockdown in place: the health check never answers, so a protected
  container that waits for it never starts, and one already running has no
  network.

### Checking the firewall from the protected container

The health check is on the loopback of the shared network: the protected
container sees it only from behind the firewall. Its entrypoint can refuse to
start without it:

```bash
if [ "$(curl -fsS -m 5 http://127.0.0.1/)" != Ok ]; then
    echo "no firewall in front of this container" >&2
    exit 1
fi
```

## Rules

```
ipv4 on
ipv6 off
internet on
allow 192.168.1.0/24 tcp 80,443
allow 192.168.1.2 tcp 8888,30000-30100
allow 10.0.0.53 udp 53
```

Each line is a switch or a rule; the defaults are `ipv4 on`, `ipv6 off`,
`internet on`, and no `allow` line.

- `ipv4 on|off`, `ipv6 on|off`: circuit breakers. `off` drops all traffic of
  that protocol, whatever the other lines say, except on loopback.
- `internet on`: any address outside the private ranges is reachable, and so
  are the DNS servers the container uses.
- `internet off`: no address outside the private ranges is reachable, and no
  DNS server either, unless an `allow` line names it. No exception for any
  provider.
- `allow <address or range> <tcp|udp> <ports>`: on the private ranges, only
  these are reachable, whether the internet is on or off.
- Everything else is dropped.
- [`examples/config`](examples/config) is a complete file.

The private ranges are `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, and for
IPv6 `fc00::/7`. `100.64.0.0/10` (carrier-grade NAT) and the link-local ranges
(`169.254.0.0/16`, `fe80::/10`, cloud metadata services) are not private: they
are only reachable through an `allow` line.

The firewall only sees direct connections: an allowed host that reaches the
internet itself (a proxy, an MCP server fetching web pages) is a way out it
cannot close.

## How it works

`firewall-rules` turns the file into an nftables table, `inet
container_firewall`, with a single `output` chain whose policy is `drop`.
Only outgoing traffic is filtered: the replies to an incoming connection
belong to it, so the circuit breakers cut both directions.

## Open questions

- Docker's embedded DNS (`127.0.0.11`) answers on loopback, so these rules do
  not see it: with `internet off`, should it be blocked too?

## License

Apache-2.0
