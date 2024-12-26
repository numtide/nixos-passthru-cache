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
    url = "github:numtide/nixos-passthru-cache/nixos-module";
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

## TODO

* Find a better project name
* Publish Docker image
* Publish Helm chart
* Publish NixOS module

