output "instances" {
  description = "Instances"
  value = [for i, v in local.instances :
    {
      index_key   = v.index_key
      name        = try(google_compute_instance.default[v.index_key].name, null)
      zone        = try(google_compute_instance.default[v.index_key].zone, null)
      subnet_id   = v.subnet_id
      internal_ip = try(google_compute_instance.default[v.index_key].network_interface.0.network_ip, null)
    }
  ]
}

output "migs" {
  description = "Managed Instance Groups"
  value = [for i, v in local.migs :
    {
      index_key      = v.index_key
      id             = try(google_compute_region_instance_group_manager.default[v.index_key].id, null)
      self_link      = try(google_compute_region_instance_group_manager.default[v.index_key].self_link, null)
      name           = try(google_compute_region_instance_group_manager.default[v.index_key].name, null)
      instance_group = try(google_compute_region_instance_group_manager.default[v.index_key].instance_group, null)
    }
  ]
}

output "autoscalers" {
  description = "Auto Scalers"
  value = [for i, v in local.autoscalers :
    {
      index_key = v.index.key
      id        = try(google_compute_region_autoscaler.default[v.index_key].id, null)
      name      = try(google_compute_region_autoscaler.default[v.index_key].name, null)
      target    = try(google_compute_region_autoscaler.default[v.index_key].target, null)
      self_link = try(google_compute_region_autoscaler.default[v.index_key].self_link, null)
    }
  ]
}

output "umigs" {
  description = "Unmanaged Instance Groups"
  value = [for i, v in local.umigs :
    {
      index_key = v.index_key
      id        = try(google_compute_instance_group.default[v.index_key].id, null)
      self_link = try(google_compute_instance_group.default[v.index_key].self_link, null)
      name      = try(google_compute_instance_group.default[v.index_key].name, null)
      zone      = try(google_compute_instance_group.default[v.index_key].zone, null)
    }
  ]
}
