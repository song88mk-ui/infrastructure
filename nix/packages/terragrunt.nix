{
  lib,
  stdenv,
}:

let
  version = "0.94.0";
  hash = "1vncwqmiwiq2h6xsbghpha8il74nrq7pmlan36a8dhg5fr6ffdf7";
  platform = "linux_amd64";

in
stdenv.mkDerivation rec {
  pname = "terragrunt";
  inherit version;

  src = builtins.fetchurl {
    url = "https://github.com/gruntwork-io/terragrunt/releases/download/v${version}/terragrunt_linux_amd64";
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
