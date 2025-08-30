# nixos-cache-proxy

**status: alpha**

Target public: companies, institutions and event organizers that want to
               reduce their egress traffic to https://cache.nixos.org.

## What is it?

This project is a (soon) battle-tested pull-thru cache for
https://cache.nixos.org you can easily deploy into your infrastructure.

Then have the clients re-configure their cache, and you have a win.

## Usage

This project is delivered as a NixOS module. Add it to your NixOS
configuration (see below) and enable the service. Local ad‑hoc runtime
via `nix run` has been removed to keep the project focused and consistent.

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
* Publish NixOS module
* Also support Docker / Helm environments
* Add NixOS VM/integration tests
