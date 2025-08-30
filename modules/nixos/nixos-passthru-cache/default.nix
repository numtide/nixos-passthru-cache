{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.services.nixos-passthru-cache;
  scheme = if cfg.forceSSL then "https" else "http";
  statsSection = lib.optionalString cfg.stats.enable ''<p>Stats: <a href="${scheme}://${cfg.hostName}${cfg.stats.path}">${cfg.stats.path}</a></p>'';
  indexPage = pkgs.replaceVars ./index.html.template {
    HOSTNAME = cfg.hostName;
    UPSTREAM = cfg.upstream;
    SCHEME = scheme;
    STATS_PATH = cfg.stats.path;
    STATS_SECTION = statsSection;
  };
in
{
  options = {
    services.nixos-passthru-cache = {
      enable = lib.mkEnableOption "Enable NixOS passthru cache";
      forceSSL = lib.mkEnableOption "Force SSL usage via ACME" // {
        default = true;
      };
      lanMode = lib.mkEnableOption "Enable LAN (Bonjour/mDNS) auto-discovery";
      upstream = lib.mkOption {
        type = lib.types.str;
        default = "https://cache.nixos.org";
        description = "Upstream binary cache URL to proxy (scheme+host, optional port/path).";
      };
      hostName = lib.mkOption {
        type = lib.types.str;
        description = "The hostname of the passthru cache";
      };
      cacheSize = lib.mkOption {
        type = lib.types.str;
        default = "200G";
        description = "Size of the cache";
      };
      inactivity = lib.mkOption {
        type = lib.types.str;
        default = "30d";
        description = "Time before cache is considered inactive";
      };
      stats = {
        enable = lib.mkEnableOption "Expose NGINX VTS (traffic status) page";
        path = lib.mkOption {
          type = lib.types.str;
          default = "/status";
          description = "Path to serve the VTS status page (HTML).";
        };
        allowLocalOnly = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Restrict access to localhost by default.";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    # LAN mode: advertise via Avahi, default hostName to system hostname,
    # and prefer plain HTTP by default (no TLS)
    services.nixos-passthru-cache.hostName = lib.mkIf cfg.lanMode (
      # In LAN mode default to mDNS hostname (hostname.local)
      lib.mkDefault (config.networking.hostName + ".local")
    );
    services.nixos-passthru-cache.forceSSL = lib.mkIf cfg.lanMode (lib.mkDefault false);
    # In LAN mode, enable stats by default and allow non-local access to stats & logs
    services.nixos-passthru-cache.stats.enable = lib.mkIf cfg.lanMode (lib.mkDefault true);
    services.nixos-passthru-cache.stats.allowLocalOnly = lib.mkIf cfg.lanMode (lib.mkDefault false);

    services.avahi = lib.mkIf cfg.lanMode {
      enable = true;
      openFirewall = lib.mkDefault true;
      publish.enable = true;
      publish.userServices = true;
      extraServiceFiles = {
        "nixos-passthru-cache.service" = ''
          <?xml version="1.0" standalone='no'?>
          <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
          <service-group>
            <name replace-wildcards="yes">%h Nix cache</name>
            <service>
              <type>_http._tcp</type>
              <port>80</port>
              <txt-record>path=/</txt-record>
              <txt-record>nix-cache=1</txt-record>
            </service>
          </service-group>
        '';
      };
    };
    networking.firewall.allowedTCPPorts = [
      443
      80
    ];
    services.nginx = {
      enable = true;
      recommendedOptimisation = lib.mkDefault true;
      recommendedProxySettings = lib.mkDefault true;
      recommendedTlsSettings = cfg.forceSSL;
      additionalModules = lib.mkIf cfg.stats.enable [ pkgs.nginxModules.vts ];
      # Add HTTP-level VTS shared memory zone when stats are enabled
      appendHttpConfig = lib.mkIf cfg.stats.enable ''
        vhost_traffic_status_zone;
      '';
      proxyCachePath."nixos-passthru-cache" = {
        enable = true;
        levels = "1:2";
        keysZoneName = "nixos-passthru-cache";
        # Put our 2TB NVME raid0 to good use
        maxSize = cfg.cacheSize;
        inactive = cfg.inactivity;
        useTempPath = false;
      };

      # TODO: test if this improves performance
      appendConfig = ''
        worker_processes auto;
      '';
      resolver.addresses =
        let
          isIPv6 = addr: builtins.match ".*:.*:.*" addr != null;
          escapeIPv6 = addr: if isIPv6 addr then "[${addr}]" else addr;
          cloudflare = [
            "1.1.1.1"
            "2606:4700:4700::1111"
          ];
          resolvers =
            if config.networking.nameservers == [ ] then cloudflare else config.networking.nameservers;
        in
        map escapeIPv6 resolvers;

      sslDhparam = config.security.dhparams.params.nginx.path;
    };

    services.nginx.virtualHosts."nixos-passthru-cache" = {
      enableACME = cfg.forceSSL;
      forceSSL = cfg.forceSSL;
      serverName = cfg.hostName;
      # Landing page (exact match)
      locations."=/" = {
        root = "${builtins.dirOf indexPage}";
        extraConfig = ''
          try_files /${builtins.baseNameOf indexPage} =404;
          default_type text/html;
        '';
      };
      locations."=/nix-cache-info" = {
        alias = "${./nix-cache-info}";
        extraConfig = ''
          add_header Content-Type text/x-nix-cache-info;
        '';
      };
      # VTS status page
      locations."${cfg.stats.path}" = lib.mkIf cfg.stats.enable {
        extraConfig = ''
          vhost_traffic_status_display;
          vhost_traffic_status_display_format html;
          ${lib.optionalString cfg.stats.allowLocalOnly ''
            allow 127.0.0.1;
            allow ::1;
            deny all;
          ''}
        '';
      };
      locations."/" = {
        recommendedProxySettings = false;
        proxyPass = cfg.upstream;
        extraConfig = ''
          proxy_cache nixos-passthru-cache;
          proxy_cache_use_stale error timeout http_500 http_502 http_503 http_504;
          proxy_cache_valid 200 60m;
          proxy_cache_valid 404 1m;

          # Proxy headers - fixed syntax
          proxy_set_header Host "${
            let
              # Extract host[:port] from URL
              m = builtins.match "^[a-zA-Z0-9+.-]+://([^/]+).*" cfg.upstream;
            in
            if m == null then cfg.upstream else builtins.head m
          }";
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_http_version 1.1;

          # To address "could not build optimal proxy_headers_hash..."
          proxy_headers_hash_max_size 512;
          proxy_headers_hash_bucket_size 128;

          # Timeouts
          proxy_connect_timeout 60s;
          proxy_send_timeout 60s;
          proxy_read_timeout 60s;

          # Buffer settings
          proxy_buffering on;
          proxy_buffer_size 16k;
          proxy_buffers 4 32k;
          proxy_busy_buffers_size 64k;

          # Optional: Add custom headers
          add_header X-Cache-Status $upstream_cache_status;
        '';
      };
    };
    security.dhparams = {
      enable = true;
      params.nginx = { };
    };

  };
}
