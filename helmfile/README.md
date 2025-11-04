# Managing Helm charts with Helmfile

We use [helmfile][helmfile] as a native way to manage the Helm chart releases.

## Pre-requisites

In order to use the configs you'll need the following tools installed:
- Helm - https://github.com/helm/helm
- Helmfile - https://github.com/helmfile/helmfile
- Helm diff plugin - https://github.com/databus23/helm-diff

Also note that you should have the necessary AWS credentials when running any operation against a
cluster. Helmfile will attempt to fetch secrets so AWS access is needed.

## Checking chart status

Similary to `terraform` we can use the `helmfile diff` command to display any potential changes that
will happend on the cluster.

e.g on dev

```bash
cd helmfile
helmfile --environment dev diff
```

You can also use a selector to match individual charts:

```bash
helmfile --environment dev -l name=external-dns diff
```

## Applying changes

When you want to apply changes on a cluster, you can either choose to do so
selectively on a particular chart (recommended) or globally on all.

Use the following command to apply on all (e.g on dev):

```bash
cd helmfile
helmfile --environment dev --interactive apply
```

It's always a good practice to use the `--interactive` flag before applying
changes. The execution will stop and wait for confirmation before applying.

## Debugging issues

You can use the `--debug` flag when using helmfile to enable debug logs. The
values used and other info will be printed that can help with the debugging
process.

## Bootstrapping a cluster

Below are the steps necessary in order to deploy all the core apps on an empty EKS cluster. The
bootstrapping process is a bit different from the regular updates because we need have a certain
order for things to properly work.

0. Update the `<environment>/values.yaml` with the specific environment values. Use one of the
   existing environments as templates on what you should fill out. Note that things will fail if a
   variable is not set.
1. Install the [CRDs][prom_crds] for the prometheus-operator chart.
2. Install the [CRDs][alb_crds] for the alb-load-balancer-controller chart.
3. Install the [CRDs][external_secret_crds] for the external-secrets chart.
4. Install the rest of the charts normally

[helmfile]: https://github.com/helmfile/helmfile
[prom_crds]: https://github.com/prometheus-community/helm-charts/blob/8a2b77a39aaffec79a6a33fc5a585bd4ca22b746/charts/kube-prometheus-stack/UPGRADE.md#from-77x-to-78x
[alb_crds]: https://github.com/kubernetes-sigs/aws-load-balancer-controller/tree/d37f75cb547c3e696e46d67dfcc4adcbe5a3044c/helm/aws-load-balancer-controller#installing-the-chart
[external_secret_crds]: https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/deploy/crds/bundle.yaml
