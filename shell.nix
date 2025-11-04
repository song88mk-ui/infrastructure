{
  system ? builtins.currentSystem,
  pins ? import ./nix/npins,
  pkgs ? import pins.nixpkgs {
    config = {
      allowUnfree = true;
    };
    inherit system;
  },
}:

pkgs.mkShell {
  NPINS_DIRECTORY = "nix/npins";
  TG_DISABLE_INIT = "false";

  packages = with pkgs; [
    npins
    actionlint
    nix
    git
    nvd
    vals
    direnv
    nixfmt
    (pkgs.callPackage ./nix/packages/terraform.nix { })
    (pkgs.callPackage ./nix/packages/terragrunt.nix { })
    kubernetes-helm
    kubectl
    helmfile
    awscli2
    aws-vault
    mongosh
    (writeShellApplication {
      name = "fmt";
      text = ''
        nixfmt ./*.nix
        nixfmt ./nix/**/*.nix
        terragrunt hcl fmt
      '';
    })
  ];
}
