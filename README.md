# Deploys a list of VMs on Google Cloud Platform

---

# Resources

- [google_compute_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance)

---

# Inputs
 

| Name             | Description                                 | Type           | Default                  |
|------------------|---------------------------------------------|----------------|--------------------------|
| project\_id      | GCP Project ID for the VMs                  | `string`       | n/a                      |
| host_project\_id | If using Shared VPC, the Host Project ID    | `string`       | null                     |
| name_prefix      | Naming Prefix for instances                 | `string`       | "instance"               |
| network          | VPC Network Name                            | `string`       | "default"                |
| machine_type     | Machine Type for the VMs                    | `string`       | "e2-micro"               | 
| network_tags     | Network Tags for the VMs                    | `list(string)` | []                       |
| image            | Install Image for the VMs                   | `string`       | "debian-cloud/debian-11" |
| startup_script   | Startup Script                              | `string`       | n/a                      | 
| deployments      | List of deployments with this configuration | `list(object)` | n/a                      |

Attributes for the `deployments` list of objects is described below

| Name         | Description                       | Type        | Default    |
|--------------|-----------------------------------|-------------|------------|
| name         | Explicit name for the VM          | `string`    | n/a        |
| machine_type | Machine Type for this specific VM | `string`    | n/a        |
| region       | GCP Region for the VM             | `string`    | n/a        |
| zone         | GCP Zone for the VM               | `string`    | n/a        |
| network      | VPC Network Name                  | `string`    | "default"  |
| subnet       | Name of the Subnetwork            | `string`    | "default"  |

## Notes:

- Region or zone must be specified.
- If name is not given, it will be auto-generated with `var.name_prefix` and the region name.

---

##2 Examples

```
project_id  = "my-project-id"
network     = "my-network-name"
name_prefix = "test1"
deployments = [
  {
     region = "us-east1"
     subnet = "default"
  },
  {
     region = "us-west1"
     subnet = "default"
  },
]
```

