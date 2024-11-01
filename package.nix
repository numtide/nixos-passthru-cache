{ pkgs, perSystem }:
let
  runtimeDeps = [
    pkgs.nginx
    pkgs.coreutils
    pkgs.gnused
  ];
in
pkgs.stdenv.mkDerivation {
  name = "nixos-cache-proxy";

  src = ./.;

  unpackPhase = "";

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/{bin,share/nixos-cache-proxy}

    cp ${./start-nginx.sh} $out/bin/nixos-cache-proxy
    cp ${./nginx.conf.template} $out/share/nixos-cache-proxy/nginx.conf.template
    cp ${./nix-cache-info} $out/share/nixos-cache-proxy/nix-cache-info

    patchShebangs $out/bin

    wrapProgram $out/bin/nixos-cache-proxy \
      --set PATH ${pkgs.lib.makeBinPath runtimeDeps} \
      --set SHARE_DIR $out/share/nixos-cache-proxy
  '';
}
