{
  lib,
  stdenv,
  fetchzip,
}:

let
  version = "1.14.9";
  hash = "sha256-F9q16JSXZqBoIx3TIUyv33kxQSVBWqTsrbgPINu/sNQ=";
  platform = "linux_amd64";

in
stdenv.mkDerivation rec {
  pname = "terraform";
  inherit version;

  src = fetchzip {
    url = "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_${platform}.zip";
    sha256 = hash;
    stripRoot = false;
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp terraform $out/bin/terraform
    chmod +x $out/bin/terraform

    runHook postInstall
  '';
}
