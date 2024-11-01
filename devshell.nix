{ pkgs, perSystem }:
pkgs.mkShell {
  # Add build dependencies
  packages = [
    pkgs.gnused
    pkgs.nginx
  ];

  # Add environment variables
  env =
    {
    };

  # Load custom bash code
  shellHook = ''

  '';
}
