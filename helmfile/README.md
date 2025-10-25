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

1. Install the `gp3` storage class. By default the EKS cluster has the `gp2` storage class which
   isn't encrypted and also doesn't use the ebs csi driver. For those reasons we skip it and set the
   default to `gp3`.
   ```
   helmfile -e <env> -l name=storage-class apply -i
   ```
2. Install the priority classes chart. This is required for the rest of the apps in order to
   establish the different priority levels during scheduling.
   ```
   helmfile -e <env> -l name=priority-class apply -i
   ```
3. Install the [CRS][prom_crds] for the prometheus-operator chart and then install the `prometheus-operator` chart.
   ```
   helmfile -e <env> -l name=prometheus-operator apply -i
   ```

[helmfile]: https://github.com/helmfile/helmfile
[prom_crds]: https://github.com/prometheus-community/helm-charts/blob/8a2b77a39aaffec79a6a33fc5a585bd4ca22b746/charts/kube-prometheus-stack/UPGRADE.md#from-77x-to-78x
