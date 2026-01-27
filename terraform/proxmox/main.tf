resource "proxmox_virtual_environment_file" "cloud_config" {
  for_each = toset(concat(local.server_names, local.agent_names))

  content_type = "snippets"
  datastore_id = var.snippets_datastore_id
  node_name    = var.snippets_node_name

  source_raw {
    data = templatefile("${path.module}/cloud-init.tpl.yaml", {
      hostname       = each.key
      username       = var.vm_user
      ssh_public_key = local.vm_ssh_public_key_content
    })

    file_name = "${each.key}.cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "k3s_server" {
  for_each = toset(local.server_names)

  name        = each.key
  description = "k3s server (control-plane) - managed by Terraform"
  tags        = var.vm_tags

  node_name = local.server_node[each.key]
  pool_id   = var.vm_pool_id

  agent {
    # Cloud images typically need qemu-guest-agent installed/enabled first.
    enabled = false
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
        address = "dhcp"
      }
    }
  }

  network_device {
    bridge = var.vm_bridge
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }
}

resource "proxmox_virtual_environment_vm" "k3s_agent" {
  for_each = toset(local.agent_names)

  name        = each.key
  description = "k3s agent (worker) - managed by Terraform"
  tags        = var.vm_tags

  node_name = local.agent_node[each.key]
  pool_id   = var.vm_pool_id

  agent {
    enabled = false
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
        address = "dhcp"
      }
    }
  }

  network_device {
    bridge = var.vm_bridge
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }
}
