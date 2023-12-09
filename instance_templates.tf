locals {
  _instance_templates = [for i, v in var.instance_templates :
    merge(v, {
      create                 = coalesce(v.create, true)
      project_id             = coalesce(v.project_id, v.project_id)
      host_project_id        = coalesce(v.host_project_id, var.host_project_id, v.project_id, var.project_id)
      name_prefix            = lower(trimspace(coalesce(v.name_prefix, "template-${i + 1}")))
      network                = coalesce(v.network_name, v.network, "default")
      can_ip_forward         = coalesce(v.can_ip_forward, false)
      disk_boot              = coalesce(v.disk_boot, true)
      disk_auto_delete       = coalesce(v.disk_auto_delete, true)
      disk_type              = coalesce(v.disk_type, "pd-standard")
      disk_size_gb           = coalesce(v.disk_size, 20)
      os_project             = coalesce(v.os_project, local.os_project)
      os                     = coalesce(v.os, local.os)
      machine_type           = coalesce(v.machine_type, local.machine_type)
      labels                 = { for k, v in coalesce(v.labels, {}) : k => lower(replace(v, " ", "_")) }
      service_account_scopes = coalescelist(v.service_account_scopes, ["cloud-platform"])
      metadata               = merge(local.metadata, v.metadata, v.ssh_key != null ? { instanceSSHKey = v.ssh_key } : {})
    })
  ]
  instance_templates = [for i, v in local._instance_templates :
    merge(v, {
      tags               = v.network_tags
      network            = "projects/${v.host_project_id}/global/networks/${v.network}"
      subnetwork_project = v.host_project_id
      subnetwork         = coalesce(v.subnet, "default")
      source_image       = coalesce(v.image, "${v.os_project}/${v.os}")
      index_key          = "${v.project_id}/${v.name_prefix}"
    }) if v.create
  ]
}

resource "google_compute_instance_template" "default" {
  for_each                = { for i, v in local.instance_templates : v.index_key => v }
  project                 = each.value.project_id
  name_prefix             = each.value.name_prefix
  description             = each.value.description
  machine_type            = each.value.machine_type
  labels                  = each.value.labels
  tags                    = each.value.tags
  metadata                = each.value.metadata
  metadata_startup_script = each.value.startup_script
  can_ip_forward          = each.value.can_ip_forward
  disk {
    disk_type    = each.value.disk_type
    disk_size_gb = each.value.disk_size
    source_image = each.value.source_image
    auto_delete  = each.value.disk_auto_delete
    boot         = each.value.disk_boot
  }
  network_interface {
    network            = each.value.network
    subnetwork_project = each.value.subnetwork_project
    subnetwork         = each.value.subnetwork
    queue_count        = 0
  }
  service_account {
    email  = each.value.service_account_email
    scopes = each.value.service_account_scopes
  }
  shielded_instance_config {
    enable_secure_boot = true
  }
}


