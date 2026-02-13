resource "proxmox_virtual_environment_file" "cloud_config" {
  for_each = toset(concat(local.server_names, local.agent_names))

  content_type = "snippets"
  datastore_id = var.snippets_datastore_id
  # Upload snippet to the same node where the VM will run
  node_name = local.vm_node[each.key]

  source_raw {
    data = templatefile("${path.module}/cloud-init.tpl.yaml", {
      hostname       = each.key
      username       = var.vm_user
      ssh_public_key = local.vm_ssh_public_key_content
      password       = var.vm_password
      ip_address     = local.vm_ips[each.key]
      netmask        = var.vm_network_netmask
      gateway        = var.vm_network_gateway
      dns_servers    = var.vm_network_dns
    })

    file_name = "${each.key}.cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "k3s_server" {
  for_each = toset(local.server_names)

  vm_id       = local.server_vm_ids[each.key]
  name        = each.key
  description = "k3s server (control-plane) - managed by Terraform"
  tags        = var.vm_tags

  node_name = local.server_node[each.key]
  pool_id   = var.vm_pool_id

  agent {
    # Enable qemu-guest-agent to report IP addresses back to Proxmox
    enabled = true
  }

  stop_on_destroy = true

  clone {
    vm_id        = var.template_vm_id
    full         = var.clone_full
    datastore_id = var.vm_datastore_id

    # Only specify source node if template is on a different node than target
    node_name = var.template_node_name != null ? var.template_node_name : null
  }

  cpu {
    cores = var.k3s_server_cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.k3s_server_memory_mb
    floating  = var.k3s_server_memory_mb
  }

  initialization {
    datastore_id      = var.vm_datastore_id
    user_data_file_id = proxmox_virtual_environment_file.cloud_config[each.key].id

    ip_config {
      ipv4 {
        address = "${local.server_ips[each.key]}/${var.vm_network_netmask}"
        gateway = var.vm_network_gateway
      }
    }

    dns {
      servers = var.vm_network_dns
    }

    # User configuration handled by cloud-init user_data only
  }

  network_device {
    bridge = var.vm_bridge
    model  = "virtio"
    mtu    = 1500
  }

  operating_system {
    type = "l26"
  }
}

resource "proxmox_virtual_environment_vm" "k3s_agent" {
  for_each = toset(local.agent_names)

  vm_id       = local.agent_vm_ids[each.key]
  name        = each.key
  description = "k3s agent (worker) - managed by Terraform"
  tags        = var.vm_tags

  node_name = local.agent_node[each.key]
  pool_id   = var.vm_pool_id

  agent {
    # Enable qemu-guest-agent to report IP addresses back to Proxmox
    enabled = true
  }

  stop_on_destroy = true

  clone {
    vm_id        = var.template_vm_id
    full         = var.clone_full
    datastore_id = var.vm_datastore_id

    # Only specify source node if template is on a different node than target
    node_name = var.template_node_name != null ? var.template_node_name : null
  }

  cpu {
    cores = var.k3s_agent_cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.k3s_agent_memory_mb
    floating  = var.k3s_agent_memory_mb
  }

  initialization {
    datastore_id      = var.vm_datastore_id
    user_data_file_id = proxmox_virtual_environment_file.cloud_config[each.key].id

    ip_config {
      ipv4 {
        address = "${local.agent_ips[each.key]}/${var.vm_network_netmask}"
        gateway = var.vm_network_gateway
      }
    }

    dns {
      servers = var.vm_network_dns
    }

    # User configuration handled by cloud-init user_data only
    # Do NOT add user_account block here - it conflicts with cloud-init
  }

  network_device {
    bridge = var.vm_bridge
    model  = "virtio"
    mtu    = 1500
  }

  operating_system {
    type = "l26"
  }
}
