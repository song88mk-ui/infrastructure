# Song88 infrastructure

The repo is the starting point for all the infrastructure components managed by the Song88 platform.

This includes, but not limited to:
- Terraform/Terragrunt modules and stacks for the different environments and setups.
- Kubernetes manifests managed with either ArgoCD or Helm/Helmfile.
- Github actions and related automation.

## Setup

We use the following tools:
- [Terraform][terraform] & [Terragrunt][terragrunt] for managing the core AWS infrastructure
- [Helm][helm]/[Helmfile][helmfile] & [Kubectl][kubectl] for managing the Kubernetes deployments of core components.
- [AWS CLI][aws_cli] & [aws-vault][aws_vault] for managing AWS credentials.

You could install all those tools on your system independently or follow the instructions below that
use [nix][nix] and [direnv][direnv] that do this automatically for a Linux system.

### Dependencies with nix and direnv

You can use [`direnv`][direnv] to install all dependencies in your current shell using
[`Nix`][nix] whenever you `cd` into project's directory. Ensure you have both nix and direnv to continue.

To enable it in your BASH, run:

```bash
echo 'source <(direnv hook bash)' >> ~/.bashrc
source <(direnv hook bash)
```

After this, whenever `.envrc` file is changed, when you enter the project directory, you should see a
message like this:

```
direnv: error .../.envrc is blocked. Run `direnv allow` to approve its content
```

Run `direnv allow` and wait for `direnv` to fetch all dependencies and prepare your shell.

## Updating infrastructure components

Ensure you've went through the [Quick Start][tg_quick_start] for Terragrunt to get familiar with the
concepts and the way it interacts with terraform.

Next ensure that you have working AWS credentials for the environment you want to update.

The following command should show you which AWS account and user you're currently using.
```
$ aws sts get-caller-identity
{
    "UserId": "AROAMLRMLLJLSDFSDFI2M:1234567890123",
    "Account": "XXXXXXXXXXXX",
    "Arn": "arn:aws:sts::XXXXXXX:assumed-role/some-iam-role/1234567890123"
}
```

Finally you can navigate to the desired environment/project under the `live` directory and run
`terragrunt` commands as usual.

[direnv]: https://direnv.net
[nix]: https://nixos.org/
[terraform]: https://developer.hashicorp.com/terraform
[terragrunt]: https://terragrunt.gruntwork.io/
[helm]: https://helm.sh/
[helmfile]: https://github.com/helmfile/helmfile
[kubectl]: https://kubernetes.io/docs/reference/kubectl/
[tg_quick_start]: https://terragrunt.gruntwork.io/docs/getting-started/quick-start/
[aws_cli]: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
[aws_vault]: https://github.com/99designs/aws-vault
