locals {
  _instances = [
    for i, v in var.instances :
    merge(v, {
      create                    = coalesce(v.create, true)
      project_id                = coalesce(v.project_id, var.project_id)
      network_project_id        = coalesce(v.network_project_id, var.network_project_id, v.project_id, var.project_id)
      name_prefix               = coalesce(v.name_prefix, "instance-${i}")
      region                    = try(coalesce(v.region, v.zone == null ? local.region : null), null)
      network                   = coalesce(v.network_name, "default")
      subnet_name               = coalesce(v.subnet_name, "default")
      os_project                = try(coalesce(v.os_project, v.image == null ? local.os_project : null), null)
      os                        = try(coalesce(v.os, v.image == null ? local.os : null), null)
      machine_type              = coalesce(v.machine_type, local.machine_type)
      can_ip_forward            = coalesce(v.can_ip_forward, false)
      service_account_scopes    = coalesce(v.service_account_scopes, local.service_account_scopes)
      region                    = try(coalesce(v.region, var.region, v.zone == null ? local.region : null), null)
      labels                    = { for k, v in coalesce(v.labels, {}) : k => lower(replace(v, " ", "_")) }
      delete_protection         = coalesce(v.delete_protection, false)
      allow_stopping_for_update = coalesce(v.allow_stopping_for_update, true)
      create_umig               = coalesce(v.create_umig, false)
      nat_ip_names              = coalesce(v.nat_ip_names, [])
    })
  ]
  __instances = [
    for i, v in local._instances :
    merge(v, {
      image  = try(coalesce(v.image, v.os_project != null && v.os != null ? "${v.os_project}/${v.os}" : null), null)
      region = coalesce(v.region, v.zone != null ? trimsuffix(v.zone, substr(v.zone, -2, 2)) : local.region)
    }) if v.create
  ]
}

# Get a list of available zones for each region
locals {
  regions = toset(flatten(concat(
    [for i, v in local.__instances : v.region if v.zone == null],
    [for i, v in local._migs : v.region]
  )))
}
data "google_compute_zones" "available" {
  for_each = local.regions
  project  = var.project_id
  region   = each.value
}

locals {
  ___instances = [
    for i, v in local.__instances :
    merge(v, {
      name = lower(trimspace(coalesce(v.name, "${v.name_prefix}-${try(local.region_codes[v.region], "error")}")))
      zone = coalesce(
        v.zone,
        try(data.google_compute_zones.available[v.region].names, null),
        "${v.region}-${element(["b", "c"], i)}"
      )
      subnet_id = "projects/${v.network_project_id}/regions/${v.region}/subnetworks/${v.subnet_name}"
      nat_ips = flatten([for nat_ip_name in v.nat_ip_names :
        {
          project_id  = v.project_id
          region      = v.region
          name        = nat_ip_name
          description = null
          address     = null
          index_key   = "${v.project_id}/${v.region}/${nat_ip_name}"
        } if length(v.nat_ip_names) > 0
      ])
    })
  ]
  instance_nat_ips = flatten([for i, v in local.___instances : [for nat_ip in v.nat_ips : nat_ip]])
}

resource "google_compute_address" "instance_nat_ips" {
  for_each      = { for i, v in local.instance_nat_ips : v.index_key => v }
  project       = each.value.project_id
  name          = each.value.name
  description   = each.value.description
  region        = each.value.region
  purpose       = null
  address_type  = "EXTERNAL"
  network_tier  = "PREMIUM"
  prefix_length = 0
  address       = each.value.address
}


/* Lookup any NAT IP Names to get the IP Address
locals {
  address_names = flatten([for i, v in ___local.instances :
    [for nat_ip_name in v.nat_ip_names :
      {
        project_id  = v.project_id
        region      = v.region
        name        = v.nat_ip_name
        v.index_key = "${v.project_id}/${v.region}/${v.nat_ip_name}"
      } if length(v.nat_ip_names) > 0
    ]
  ])
}
data "google_compute_addresses" "address_names" {
  for_each = { for i, v in local.instances : v.index_key => v }
  project  = each.value.project_id
  region   = each.value.region
  filter   = "name:${each.value.name}"
}
*/

locals {
  ____instances = [for i, v in local.___instances :
    merge(v, {
      nat_ips = [for nat_ip in v.nat_ips :
        {
          address = google_compute_address.instance_nat_ips[nat_ip.index_key].address
        }
      ]
    })
  ]
  instances = [for i, v in local.____instances :
    merge(v, {
      #subnet_id = "projects/${v.network_project_id}/regions/${v.region}/subnetworks/${v.subnet_name}"
      index_key = "${v.project_id}/${v.zone}/${v.name}"
    }) if v.create == true
  ]
}

resource "random_string" "instance_names" {
  for_each = { for i, v in local.instances : v.index_key => true if v.name == null && v.name_prefix == null }
  length   = 5
  special  = false
  upper    = false
}

resource "google_compute_instance" "default" {
  for_each            = { for i, v in local.instances : v.index_key => v }
  name                = each.value.name
  description         = each.value.description
  zone                = each.value.zone
  project             = each.value.project_id
  machine_type        = each.value.machine_type
  can_ip_forward      = each.value.can_ip_forward
  deletion_protection = each.value.delete_protection
  boot_disk {
    initialize_params {
      type  = each.value.boot_disk_type
      size  = each.value.boot_disk_size
      image = each.value.image
    }
  }
  dynamic "network_interface" {
    for_each = each.value.network != null && each.value.subnet_name != null ? [true] : []
    content {
      network            = each.value.network
      subnetwork_project = each.value.network_project_id
      subnetwork         = each.value.subnet_name
      dynamic "access_config" {
        for_each = each.value.nat_ips
        content {
          nat_ip = each.value.nat_ips[0].address
        }
      }
    }
  }
  labels = {
    #os           = coalesce(each.value.os, strcontains(each.value.image, "/") ? split("/", each.value.image)[-1] : "")
    os           = coalesce(each.value.os, split("/", each.value.image)[1])
    image        = each.value.image != null ? substr(replace(each.value.image, "/", "-"), 0, 63) : null
    machine_type = each.value.machine_type
  }
  tags = each.value.network_tags
  #metadata_startup_script = each.value.startup_script
  metadata = each.value.startup_script != null || each.value.ssh_key != null ? {
    startup-script = each.value.startup_script
    instanceSSHKey = each.value.ssh_key
  } : null
  service_account {
    email  = each.value.service_account_email
    scopes = each.value.service_account_scopes
  }
  allow_stopping_for_update = each.value.allow_stopping_for_update
}

