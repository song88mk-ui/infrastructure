# MongoDB setup

## Mount and format the EBS volume

Mount and format the dedicated EBS volume used for MongoDB data using the volumes playbook. Run this
playbook only once per instance: during initial creation and when adding new instances to a MongoDB
cluster.

```bash
ansible-playbook -i inventory/<ENV>.yml playbooks/volumes.yml --private-key ~/.ssh/mongodb-<ENV> --check
```

Replace `<ENV>` with the target environment. Use the corresponding inventory file and SSH key for
that environment. SSH keys are stored in 1Password.

## Provision the MongoDB instance

Provision the instance using the `mongodb.yml` playbook, which performs the following:

- Tunes the Linux VM for MongoDB.
- Adds the repository and installs the MongoDB service.
- Creates an admin user with a password stored in AWS SSM.
- Sets up the initial `rs0` replica.
- Installs `node_exporter` for Prometheus host metrics.
