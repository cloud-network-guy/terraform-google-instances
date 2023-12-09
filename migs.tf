locals {
  _migs = [for i, v in var.migs :
    merge(v, {
      create     = coalesce(v.create, true)
      project_id = coalesce(v.project_id, var.project_id)
      #host_project_id                       = coalesce(v.host_project_id, var.host_project_id, v.project_id, var.project_id)
      base_instance_name                    = coalesce(v.base_instance_name, v.name_prefix)
      region                                = coalesce(v.region, var.region)
      distribution_target_shape             = upper(coalesce(v.distribution_policy_target_shape, "EVEN"))
      update_type                           = upper(coalesce(v.update_type, "OPPORTUNISTIC"))
      update_instance_redistribution_type   = upper(coalesce(v.update_instance_redistribution_type, "PROACTIVE"))
      update_minimal_action                 = upper(coalesce(v.update_minimal_action, "RESTART"))
      update_most_disruptive_allowed_action = upper(coalesce(v.update_most_disruptive_action, "REPLACE"))
      replacement_method                    = upper(coalesce(v.update_replacement_method, "SUBSTITUTE"))
      initial_delay_sec                     = coalesce(v.auto_healing_initial_delay, 300)
    })
  ]
}

locals {
  __migs = [for i, v in local._migs :
    merge(v, {
      name             = coalesce(v.name, v.name_prefix, "mig-${i}")
      hc_prefix        = "projects/${v.project_id}/${v.region != null ? "regions/${v.region}" : "global"}"
      zones            = try(data.google_compute_zones.available[v.region].names, [for z in ["b", "c"] : "${v.region}-${z}"])
      autoscaling_mode = upper(coalesce(v.autoscaling_mode, v.min_replicas != null || v.max_replicas != null ? "ON" : "OFF"))
      is_regional      = v.region != null ? true : false
    })
  ]
  migs = [for i, v in local.__migs :
    merge(v, {
      version_name = "${v.name}-0"
      target_size  = v.autoscaling_mode == null ? coalesce(v.target_size, 2) : null
      healthchecks = [for hc in v.healthchecks :
        {
          id = coalesce(hc.id, hc.name != null ? "${v.hc_prefix}/healthChecks/${hc.name}" : null)
        }
      ]
      update_max_unavailable_fixed = length(v.zones)
      update_max_surge_fixed       = length(v.zones)
      index_key                    = "${v.project_id}/${v.region}/${v.name}"
      instance_template_key        = "${v.project_id}/${v.name_prefix}"
    }) if v.create
  ]
}


# Regional Managed Instance Groups
resource "google_compute_region_instance_group_manager" "default" {
  for_each                         = { for i, v in local.migs : v.index_key => v if v.is_regional }
  project                          = each.value.project_id
  base_instance_name               = each.value.base_instance_name
  name                             = each.value.name
  region                           = each.value.region
  distribution_policy_target_shape = each.value.distribution_policy_target_shape
  distribution_policy_zones        = each.value.zones
  target_size                      = each.value.target_size
  wait_for_instances               = false
  version {
    name              = each.value.version_name
    instance_template = try(google_compute_instance_template.default[each.value.instance_template_key].id, null)
  }
  dynamic "auto_healing_policies" {
    for_each = each.value.healthchecks
    content {
      health_check      = auto_healing_policies.value.id
      initial_delay_sec = each.value.initial_delay_sec
    }
  }
  update_policy {
    type                           = each.value.update_type
    instance_redistribution_type   = each.value.update_instance_redistribution_type
    minimal_action                 = each.value.update_minimal_action
    most_disruptive_allowed_action = each.value.update_most_disruptive_action
    replacement_method             = each.value.update_replacement_method
    max_unavailable_fixed          = each.value.update_max_unavailable_fixed
    max_surge_fixed                = each.value.update_max_surge_fixed
  }
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [distribution_policy_zones]
  }
  timeouts {
    create = "5m"
    update = "5m"
    delete = "15m"
  }
  depends_on = [google_compute_instance_template.default]
}

