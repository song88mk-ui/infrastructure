{
  lib,
  stdenv,
}:

let
  version = "0.91.2";
  hash = "1b1fxpibisynj3n2g7li35270x5cbkgdhsv6ppcr7i4vq6kx83z4";
  platform = "linux_amd64";

in
stdenv.mkDerivation rec {
  pname = "terragrunt";
  inherit version;

  src = builtins.fetchurl {
    url = "https://github.com/gruntwork-io/terragrunt/releases/download/v0.91.2/terragrunt_linux_amd64";
    sha256 = hash;
  };

  dontUnpack = true;
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/terragrunt
    chmod +x $out/bin/terragrunt

    runHook postInstall
  '';
}
