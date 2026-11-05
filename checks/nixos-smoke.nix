{ pkgs, ... }:
let
  module = import ../modules/nixos/nixos-passthru-cache;
  system = pkgs.stdenv.hostPlatform.system;
in
if system == "aarch64-linux" then
  pkgs.runCommand "nixos-passthru-cache-smoke-disabled-${system}" { } ''
    mkdir -p $out
    echo "disabled on ${system}" > $out/message
  ''
else pkgs.nixosTest {
  name = "nixos-passthru-cache-smoke";

  nodes.machine = { pkgs, ... }: {
    imports = [ module ];

    # Fake upstream served by the same nginx on 127.0.0.1:1234
    services.nginx.virtualHosts."fake-upstream" = {
      listen = [{ addr = "127.0.0.1"; port = 1234; ssl = false; }];
      serverName = "fake-upstream";
      locations."/".extraConfig = ''
        add_header Cache-Control "max-age=3600";
        add_header X-Fake-Upstream 1;
        return 200 "hello from upstream\n";
      '';
    };

    services.nixos-passthru-cache = {
      enable = true;
      forceSSL = false;
      hostName = "cache.local";
      upstream = "http://127.0.0.1:1234";
      stats.enable = true;
    };

    # Keep things simple for the test
    networking.firewall.enable = false;
    environment.systemPackages = [ pkgs.curl ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("nginx.service")
    machine.wait_for_open_port(80)
    machine.wait_for_open_port(1234)

    # nix-cache-info served with correct content-type and content
    machine.succeed("curl -sSfI http://localhost/nix-cache-info | grep -qi 'content-type: text/x-nix-cache-info'")
    machine.succeed("curl -sSf http://localhost/nix-cache-info | grep -q '^StoreDir:'")

    # Cache MISS then HIT against fake upstream
    machine.succeed("curl -sSfi http://localhost/foo | tee /tmp/res1 | grep -qi '^X-Cache-Status: MISS' || (echo 'expected MISS' && cat /tmp/res1 && false)")
    machine.succeed("curl -sSfi http://localhost/foo | tee /tmp/res2 | grep -qi '^X-Cache-Status: HIT' || (echo 'expected HIT' && cat /tmp/res2 && false)")

    # VTS status page reachable (HTML)
    machine.succeed("curl -sSfI http://localhost/status | grep -q '200'")
  '';
}
