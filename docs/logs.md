# Application logs

In order to view the application logs live you can do the following, assuming you have EKS access
already setup. If not, refer to [this](.docs/eks-access.md) guide.

The following command will give you all the running docker containers in the cluster:

```bash
$ kubectl get pods -n bet-genius-apps
bg-engine-sportsbook-84fb5b48b5-lnmwq     1/1     Running   0              111m
bg-feed-receiver-api-cbc45879-44pkz       1/1     Running   0              2m56s
bg-feed-receiver-api-cbc45879-xkwnv       1/1     Running   0              2m58s
bg-rabbitmq-api-6db9f877d-xrbml           1/1     Running   1 (2m4s ago)   111m
bg-receiver-service-c8b6f586f-ts9nm       1/1     Running   0              111m
mongodb-569678d9cb-9lkdb                  1/1     Running   0              3d22h
mssql-mssqlserver-2022-56bf8c689d-4fp9d   1/1     Running   0              3d22h
rabbitmq-main-cluster-server-0            1/1     Running   0              3d22h
```

Next you can select a pod the view the logs in the console with the following command:

```bash
kubectl logs bg-feed-receiver-api-cbc45879-xkwnv -f
```

The `-f` flag will keep following the logs as they are generated.
