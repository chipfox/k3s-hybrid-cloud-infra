locals {
  server_names = [for i in range(var.k3s_server_count) : "k3st-${i + 1}"]
  agent_names  = [for i in range(var.k3s_agent_count) : "k3st-a${i + 1}"]

  # Round-robin placement across Proxmox nodes
  server_node = {
    for idx, name in local.server_names :
    name => element(var.proxmox_nodes, idx % length(var.proxmox_nodes))
  }

  agent_node = {
    for idx, name in local.agent_names :
    name => element(var.proxmox_nodes, idx % length(var.proxmox_nodes))
  }

  vm_node = merge(local.server_node, local.agent_node)

  # Read SSH public key from file path
  vm_ssh_public_key_content = file(var.vm_ssh_public_key)
}
