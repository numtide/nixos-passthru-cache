# nixos-passthru-cache

Stop paying to download the same bytes twice.

Status: Beta - solid core; interfaces may still change.

Maintained by Numtide.

## What It Is

A drop‑in, pull‑through cache for Nix. Put it on your network, point your machines at it, and watch egress fall while builds get faster.

## Who It’s For

Infra and platform teams running many Nix machines - enterprises, universities, events. Anywhere repeating downloads hurt cost and speed.

## Why It Matters

cache.nixos.org serves billions of requests and petabytes of data every month. Caching locally keeps those bytes close - and your bill lower.

## Quick Start (Server on NixOS)

In your `flake.nix`:

```
inputs = {
  nixos-passthru-cache = {
    url = "github:numtide/nixos-passthru-cache";
    inputs.blueprint.follows = "blueprint";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

In your NixOS configuration:

```
{
  imports = [ inputs.nixos-passthru-cache.nixosModules.nixos-passthru-cache ];

  services.nixos-passthru-cache.enable = true;
  services.nixos-passthru-cache.hostName = "cache.example.org";
  # Optional: change upstream (defaults to https://cache.nixos.org)
  # services.nixos-passthru-cache.upstream = "https://my-upstream-cache.example";
  # Optional: adjust cache size (default 200G)
  # services.nixos-passthru-cache.cacheSize = "500G";
}
```

TLS/ACME (when `forceSSL = true`, the default):

```
security.acme = {
  acceptTerms = true;
  defaults.email = "ops@example.org";
};
```

## Point Clients At It

NixOS:

```nix
{
  nix.settings.extra-substituters = [ "https://cache.example.org" ];
}
```

`nix.conf`:

```
extra-substituters = https://cache.example.org
```

## Validate

```
curl -I https://cache.example.org/nix-cache-info
```

Look for HTTP 200. You’ll also see `X-Cache-Status` headers on proxied requests.

## Zero‑Config LAN Mode (Bonjour/mDNS)

For trusted LANs: discoverable, no‑TLS, mDNS hostname (`hostname.local`).

```nix
{
  services.nixos-passthru-cache.enable = true;
  services.nixos-passthru-cache.lanMode = true;
  # hostName defaults to networking.hostName + ".local"
  # TLS (forceSSL) defaults to false
}
```

This publishes an `_http._tcp` Bonjour service on port 80 via Avahi and opens mDNS in the firewall.

## Traffic Stats (NGINX VTS)

See traffic, hit/miss, and cache health.

- Path: `/status`
- Defaults: enabled in LAN mode; otherwise off and localhost‑only

Enable explicitly when not in LAN mode:

```nix
{
  services.nixos-passthru-cache.enable = true;
  services.nixos-passthru-cache.stats.enable = true;
  # Optional: open beyond localhost
  # services.nixos-passthru-cache.stats.allowLocalOnly = false;
}
```

Visit `https://cache.example.org/status` (or `http://` in LAN mode).

## Demo Cache (Best‑Effort)

- Hetzner (Frankfurt): https://hetzner-cache.numtide.com — useful if you run in Hetzner networks
- Uplink: 1G • Hardware: AX52

Use it from NixOS:

```nix
{
  nix.settings.extra-substituters = [ "https://hetzner-cache.numtide.com" ];
}
```

Or from `nix.conf`:

```
extra-substituters = https://hetzner-cache.numtide.com
```

## Operate

- Default cache size: 200G (tunable)
- Ports: 80/443 (TLS on by default unless LAN mode)
- Health: `curl -I /nix-cache-info` and check `/status` if enabled

## Support

Maintained by Numtide. Issues and contributions welcome.

## License

MIT — see `LICENSE`.
