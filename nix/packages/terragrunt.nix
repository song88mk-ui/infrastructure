{
  lib,
  stdenv,
}:

let
  version = "0.92.1";
  hash = "175bqkvl1pl3ycqlar0p6r69ak5w9gnnbzbm0c5pbl704v7ppvr4";
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
