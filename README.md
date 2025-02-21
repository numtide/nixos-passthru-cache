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
  # services.nixos-passthru-cache.cacheSize = "200G"; # Maximum cache size, 200GB is the default
}
```

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

