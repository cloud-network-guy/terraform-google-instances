
locals {
  autoscalers = [for i, v in local.migs :
    {
      project_id            = v.project_id
      name                  = v.name_prefix
      region                = v.region
      target                = try(google_compute_region_instance_group_manager.default[v.index_key].self_link, null)
      mode                  = v.autoscaling_mode
      min_replicas          = v.autoscaling_mode != "OFF" ? coalesce(v.min_replicas, 1) : 0
      max_replicas          = v.autoscaling_mode != "OFF" ? coalesce(v.max_replicas, 10) : 0
      cooldown_period       = coalesce(v.cooldown_period, 60)
      cpu_target            = coalesce(v.cpu_target, 0.60)
      cpu_predictive_method = coalesce(v.cpu_predictive_method, "NONE")
      is_regional           = v.is_regional
      index_key             = v.index_key
    } if v.autoscaling_mode != "OFF"
  ]
}
resource "google_compute_region_autoscaler" "default" {
  for_each = { for i, v in local.autoscalers : v.index_key => v if v.is_regional }
  name     = each.value.name
  project  = each.value.project_id
  region   = each.value.region
  target   = each.value.target
  autoscaling_policy {
    max_replicas    = each.value.max_replicas
    min_replicas    = each.value.min_replicas
    cooldown_period = each.value.cooldown_period
    mode            = each.value.mode
    cpu_utilization {
      target            = each.value.cpu_target
      predictive_method = each.value.cpu_predictive_method
    }
  }
}