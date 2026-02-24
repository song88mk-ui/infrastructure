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
    argocd
    (pkgs.callPackage ./nix/packages/terraform.nix { })
    (pkgs.callPackage ./nix/packages/terragrunt.nix { })
    kubernetes-helm
    kubectl
    helmfile
    awscli2
    aws-vault
    mongosh
    mongodb-tools
    sqlcmd
    (writeShellApplication {
      name = "fmt";
      text = ''
        nixfmt ./*.nix
        nixfmt ./nix/**/*.nix
        terragrunt hcl fmt
      '';
    })
  ];

  shellHook = ''
    export LC_ALL=en_US.utf-8
  '';
}
