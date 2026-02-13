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
  vm_ssh_public_key_content = trimspace(file(var.vm_ssh_public_key))

  # Calculate static IPs for each VM
  # Parse base IPs and increment
  server_ip_parts = split(".", var.k3s_server_ip_base)
  agent_ip_parts  = split(".", var.k3s_agent_ip_base)

  server_ips = {
    for idx, name in local.server_names :
    name => format(
      "%s.%s.%s.%d",
      local.server_ip_parts[0],
      local.server_ip_parts[1],
      local.server_ip_parts[2],
      tonumber(local.server_ip_parts[3]) + idx
    )
  }

  agent_ips = {
    for idx, name in local.agent_names :
    name => format(
      "%s.%s.%s.%d",
      local.agent_ip_parts[0],
      local.agent_ip_parts[1],
      local.agent_ip_parts[2],
      tonumber(local.agent_ip_parts[3]) + idx
    )
  }

  # Merge all IPs for easy lookup
  vm_ips = merge(local.server_ips, local.agent_ips)

  # Assign unique VM IDs for servers and agents
  server_vm_ids = {
    for idx, name in local.server_names :
    name => var.k3s_server_vm_id_base + idx
  }

  agent_vm_ids = {
    for idx, name in local.agent_names :
    name => var.k3s_agent_vm_id_base + idx
  }
}
