# nixos-cache-proxy

**status: alpha**

Target public: companies, institutions and event organizers that want to
               reduce their egress traffic to https://cache.nixos.org.

## What is it?

This project is a (soon) battle-tested pull-thru cache for
https://cache.nixos.org you can easily deploy into your infrastructure.

Then have the clients re-configure their cache, and you have a win.

## Usage

Clone the repo and execute `nix run` to launch the cache on port 8080.
More options will be made available later.

## Configuration

* `$CACHE_ADDR`: on which port to bind the server (default: `[::]:8080`)
* `$CACHE_DIR`: where the state will be stored. (default: `$PWD/data`)
* `$CACHE_SIZE`: how much data to store on disk. (default: `10g`)

## Usage in NixOS

in your flake.nix:

```
inputs = {
  nixos-passthru-cache = {
    url = "github:numtide/nixos-passthru-cache";
    inputs.blueprint.follows = "blueprint";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

in your nixos configuration:

```
{
  imports = [
    inputs.nixos-passthru-cache.nixosModules.nixos-passthru-cache
  ];

  services.nixos-passthru-cache.hostName = "cache.your-domain.com";
  # Optional: change upstream (defaults to https://cache.nixos.org)
  # services.nixos-passthru-cache.upstream = "https://my-upstream-cache.example";
  # services.nixos-passthru-cache.cacheSize = "200G"; # Maximum cache size, 200GB is the default
}
```

### LAN mode (Bonjour/mDNS)

Enable LAN auto-discovery and default to the machine hostname with TLS disabled. In LAN mode, the default hostname becomes `hostname.local` for mDNS:

```nix
{
  services.nixos-passthru-cache.enable = true;
  services.nixos-passthru-cache.lanMode = true;
  # hostName will default to networking.hostName + ".local"; TLS (forceSSL) defaults to false
}
```
This publishes an `_http._tcp` Bonjour service on port 80 via Avahi and opens mDNS in the firewall.

### Traffic Stats (NGINX VTS)

In LAN mode, stats are enabled by default and exposed at `/status`. Otherwise, enable explicitly. Access is localhost-only unless LAN mode.

```nix
{
  services.nixos-passthru-cache.enable = true;
  # LAN mode auto-enables stats and opens them beyond localhost
  # services.nixos-passthru-cache.lanMode = true;
  # Otherwise, enable explicitly and set ACLs:
  # services.nixos-passthru-cache.stats.enable = true;
  # services.nixos-passthru-cache.stats.allowLocalOnly = false;
}
```
Visit `https://<host>/status` (or `http://` if LAN mode) to view metrics.

## Demo instances

- We have deployed a binary cache at [https://hetzner-cache.numtide.com](https://hetzner-cache.numtide.com) for testing local caching in hetzner networks.
- Location: Frankfurt, Uplink: 1G, Hardware: [AX52](https://www.hetzner.com/dedicated-rootserver/ax52/)

Using this binary cache in your nixos configuration:

```nix
{
  nix.settings.extra-substituters = [ "https://hetzner-cache.numtide.com" ];
}
```

in your nix.conf

```
extra-substituters = https://hetzner-cache.numtide.com
```


## TODO

* Find a better project name
* Publish Docker image
* Publish Helm chart
* Publish NixOS module
