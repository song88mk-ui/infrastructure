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

## Creation of a new environment

All the terragrunt configuration can be found under the `live` directory. The first level should be a
list of the AWS accounts we maintain (e.g `aws-plat-dev`). Under that level there are the
environments that can be found in the account. An environment is a collection of resources that work
together to server common purpose. Finally on each environments we have components which are pieces
of infrastructure like an RDS server, an EC2 instance etc. The more granular the approach we take
when defining environments and components the better as this will better allow us to make
modification faster and independently.

The example below shows two AWS accounts (`aws-plat-dev` & `aws-plat-prod`) with different
environments and the same components.

```bash
$ tree live

live
└── aws-plat-dev
    └── account.hcl
    └── sandbox
        ├── eks
        ├── env.hcl
        ├── mongodb
        ├── mssql-server
        ├── mssql-server-sg
        ├── rabbitmq
        └── vpc
    └── staging
        ├── eks
        ├── env.hcl
        ├── mongodb
        ├── mssql-server
        ├── mssql-server-sg
        ├── rabbitmq
        └── vpc
└── aws-plat-prod
    └── account.hcl
    └── prod
        ├── eks
        ├── env.hcl
        ├── mongodb
        ├── mssql-server
        ├── mssql-server-sg
        ├── rabbitmq
        └── vpc
```

Adding a new environment will be copying over the structure from an existing environment and
adjusting the components accordingly.

The two important files to consider are `env.hcl` which contains the variables and configs specific
to that environment. e.g name, vpc prefix and the `terragrunt.hcl` at the root of each environment
which contains the configuration for the s3 backend that will be used to store the terraform state.
We use different backends for each environment to keep them separated.

Once you've created the environment structure, you can start creating the environment with the
following commands, for each component.

```bash
cd <aws-account>/<env>/<component>
terragrunt apply
```

You can go over the [examples][terragrunt_live] repo for Terragrunt for more information.

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
[terragrunt_live]: https://github.com/gruntwork-io/terragrunt-infrastructure-live-stacks-example
