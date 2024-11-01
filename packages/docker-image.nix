{ pkgs, perSystem }:
pkgs.dockerTools.buildLayeredImage {
  name = "nixos-passthru-cache";

  config = {
    Cmd = [ "${perSystem.self.default}/bin/nixos-cache-proxy" ];
    Env = [ "WORK_DIR=/data" ];
    WorkingDir = "/data";
    Volumes = {
      "/data" = { };
    };
  };
}
