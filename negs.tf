
locals {
  _negs = [for i, v in var.negs :
    merge(v, {
      create          = coalesce(v.create, true)
      project_id      = coalesce(v.project_id, var.project_id)
      host_project_id = coalesce(v.host_project_id, var.host_project_id, v.project_id, var.project_id)
      name            = lower(trimspace(coalesce(v.name, "neg-${i + 1}")))
      network         = coalesce(v.network, "default")
      subnet          = coalesce(v.network, "default")
      default_port    = coalesce(v.default_port, 443)
      region          = coalesce(v.region, var.region, "global")
      is_psc          = v.psc_target != null ? true : false
    })
  ]
  __negs = [for i, v in local._negs :
    merge(v, {
      is_global   = v.region == "global" ? true : false
      is_regional = v.region != "global" && v.zone == null ? true : false
      is_regional = v.zone != null ? true : false
      network     = startswith(v.network, local.url_prefix) ? replace(v.network, local.url_prefix, "") : v.network
      subnetwork  = startswith(v.subnet, local.url_prefix) ? replace(v.subnet, local.url_prefix, "") : v.subnet
      endpoints = [for e in coalesce(v.endpoints, []) :
        merge(e, {
          project_id = v.project_id
          fqdn       = lookup(e, "fqdn", v.fqdn)
          ip_address = lookup(e, "ip_address", v.ip_address)
          port       = lookup(e, "port", v.default_port)
        })
      ]
    })
  ]
  negs = [for i, v in local.__negs :
    merge(v, {
      network    = startswith(v.network, "projects/") ? v.network : "projects/${v.host_project_id}/global/networks/${v.network}"
      subnetwork = startswith(v.subnet, "projects/") ? v.subnet : "projects/${v.host_project_id}/regions/${v.region}/subnetworks/${v.subnet}"
      network_endpoint_type = one(coalescelist(
        set([for e in v.endpoints : "INTERNET_FQDN_PORT" if e.fqdn != null]),
        set([for e in v.endpoints : "INTERNET_IP_PORT" if e.ip_address != null]),
        ["UNKNOWN"]
      ))
    }) if v.create == true
  ]
}

locals {
  _gnegs = [for i, v in local.negs :
    merge(v, {
      network   = null
      subnet    = null
      index_key = "${v.project_id}/${v.name}"
    }) if v.is_global && !v.is_psc
  ]
  gnegs = [for i, v in local._gnegs :
    merge(v, {
      endpoints = [for e in v.endpoints :
        merge(e, {
          index_key       = "${e.project_id}/${v.name}/${try(coalesce(e.ip_address), "")}/${try(coalesce(e.fqdn), "")}/${e.port}"
          group_index_key = v.index_key
        })
      ]
    }) if v.create == true
  ]
}

# Global Network Endpoint Groups
resource "null_resource" "gnegs" {
  for_each = { for i, v in local.gnegs : v.index_key => true }
}
resource "google_compute_global_network_endpoint_group" "default" {
  for_each              = { for i, v in local.gnegs : v.index_key => v }
  project               = each.value.project_id
  name                  = each.value.name
  network_endpoint_type = each.value.network_endpoint_type
  default_port          = each.value.default_port
  depends_on            = [null_resource.gnegs]
}
# Global Network Endpoints
resource "google_compute_global_network_endpoint" "default" {
  for_each                      = { for i, v in local.gnegs.endpoints : v.index_key => v }
  project                       = each.value.project_id
  global_network_endpoint_group = google_compute_global_network_endpoint_group.default[each.value.group_index_key].id
  fqdn                          = each.value.fqdn
  ip_address                    = each.value.ip_address
  port                          = each.value.port
}

locals {
  _rnegs = [for i, v in local.negs :
    merge(v, {
      network_endpoint_type = v.is_psc ? "PRIVATE_SERVICE_CONNECT" : "SERVERLESS"
      endpoints = [for e in v.endpoints :
        merge(e, {
          fqdn       = lookup(e, "fqdn", null)
          ip_address = lookup(e, "ip_address", null)
          port       = lookup(e, "port", v.default_port)
        })
      ]
      index_key = "${v.project_id}/${v.region}/${v.name}"
    }) if v.region != "global" && v.zone == null
  ]
  rnegs = [for i, v in local._rnegs :
    merge(v, {
      network    = v.is_psc ? null : v.network
      subnetwork = v.is_psc ? v.subnetwork : null
      endpoints = [for e in v.endpoints :
        merge(e, {
          #index_key       = "${e.project_id}/${v.name}/${try(coalesce(e.ip_address), "")}/${try(coalesce(e.fqdn), "")}/${e.port}"
          group_index_key = v.index_key
        })
      ]
    }) if v.create == true
  ]
}
# Regional Network Endpoint Group
resource "null_resource" "rnegs" {
  for_each = { for i, v in local.rnegs : v.index_key => true }
}
resource "google_compute_region_network_endpoint_group" "default" {
  for_each              = { for i, v in local.rnegs : v.index_key => v }
  project               = each.value.project_id
  name                  = each.value.name
  network_endpoint_type = each.value.network_endpoint_type
  region                = each.value.region
  psc_target_service    = each.value.psc_target_service
  network               = each.value.network
  subnetwork            = each.value.subnetwork
  dynamic "cloud_run" {
    for_each = each.value.cloud_run_service != null ? [true] : []
    content {
      service = each.value.cloud_run_service
    }
  }
  depends_on = [null_resource.rnegs]
}
# Regional Network Endpoints
resource "google_compute_region_network_endpoint" "default" {
  for_each                      = { for i, v in local.rnegs.endpoints : v.index_key => v }
  project                       = each.value.project_id
  region_network_endpoint_group = google_compute_region_network_endpoint_group.default[each.value.group_index_key].id
  fqdn                          = each.value.fqdn
  ip_address                    = each.value.ip_address
  port                          = each.value.port
  region                        = each.value.region
  depends_on                    = [null_resource.rnegs]
}

locals {
  _znegs = [for i, v in local.negs :
    merge(v, {
      endpoints = [for e in v.endpoints :
        merge(e, {
          fqdn       = lookup(e, "fqdn", null)
          ip_address = lookup(e, "ip_address", null)
          port       = lookup(e, "port", v.default_port)
        })
      ]
      index_key = "${v.project_id}/${v.zone}/${v.name}"
    }) if v.zone != null
  ]
  znegs = [for i, v in local._znegs :
    merge(v, {
      endpoints = [for e in v.endpoints :
        merge(e, {
          #index_key       = "${e.project_id}/${v.name}/${try(coalesce(e.ip_address), "")}/${try(coalesce(e.fqdn), "")}/${e.port}"
          group_index_key = v.index_key
        })
      ]
    }) if v.create == true
  ]
}
# Zonal Network Endpoint Group
resource "null_resource" "znegs" {
  for_each = { for i, v in local.znegs : v.index_key => true }
}
resource "google_compute_network_endpoint_group" "default" {
  for_each              = { for i, v in local.znegs : v.index_key => v }
  project               = each.value.project_id
  name                  = each.value.name
  network_endpoint_type = each.value.network_endpoint_type
  zone                  = each.value.zone
  network               = each.value.network
  subnetwork            = each.value.subnetwork
  default_port          = each.value.default_port
  depends_on            = [null_resource.znegs]
}
# Zonal Network Endpoint
resource "google_compute_network_endpoint" "default" {
  for_each               = { for i, v in local.znegs : v.index_key => v }
  project                = each.value.project_id
  network_endpoint_group = google_compute_network_endpoint_group.default[each.value.group_index_key].id
  zone                   = each.value.zone
  instance               = each.value.instance
  ip_address             = each.value.ip_address
  port                   = each.value.port
  depends_on             = [null_resource.znegs]
}