# See https://nixos.wiki/wiki/Packaging/Ruby
# A small helper script to get a development version for redmine/mis under NixOS
with import <nixpkgs> {};
stdenv.mkDerivation {
  name = "env";
  buildInputs = [
    ruby_2_6.devEnv
    git
    sqlite
    libpcap
    postgresql
    libxml2
    libxslt
    pkg-config
    bundix
    gnumake
    imagemagick
    ghostwriter
  ];
}
