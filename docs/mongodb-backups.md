# MongoDB backups and restore

The guide describes how to create a database dump from a MongoDB server and be able to
restore it on another server.

## Export all databases

We'll be running the following command for all the existing databases:
- `Trading`
- `Sportsbook`

You might need to adjust the timeout depending on your connection and the size of the database:

```bash
mongodump \
    --gzip \
    --uri="mongodb://<USERNAME>:<PASSWORD>@<REMOTE_SERVER>:27017/<DB_NAME>?tls=false&socketTimeoutMS=300000&connectTimeoutMS=300000" \
    --out=mongodb-dump
```

All the database will be under the `mongodb-dump` directory.

```bash
$ ls mongodb-dump
Sportsbook
Trading
```

## Restore all databases

We can restore all exported databases into the new MongoDB server using the following command:

```bash
mongorestore \
    --uri="mongodb://<USERNAME>:<PASSWORD>@<REMOTE_SERVER>:27017/?tls=false" mongodb-dump
```

> [!WARNING]
> If you're restoring data from MongoDB v8 to DocumentDB v8 use mongo-tools v100.7.x or earlier
> because the latest versions are not compatible. See
https://github.com/documentdb/documentdb/issues/148 for more.


## Apply admin permissions

```
use admin

// Ensure our new user has admin access on all the restore databases.
db.grantRolesToUser("admin", [
  { role: "dbAdmin", db: "Trading" },
  { role: "dbAdmin", db: "Sportsbook" }
])
```

> [!TIP]
> If you're migrating data from a database deployed in kubernetes you can use the following manifest
> to create a proxy instance to speed up the process.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongo-backup-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 25Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: mongo-migrate
spec:
  containers:
    - name: mongo-migrate
      image: mongo:latest
      command: ["sleep", "infinity"]
      volumeMounts:
        - name: backup-volume
          mountPath: /backup
  volumes:
    - name: backup-volume
      persistentVolumeClaim:
        claimName: mongo-backup-pvc
  restartPolicy: Never
```

Then exec into the pod with `kubectl exec -it mongo-migrate -- bash`.
