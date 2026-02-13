output "k3s_server_names" {
  value = sort([for vm in proxmox_virtual_environment_vm.k3s_server : vm.name])
}

output "k3s_agent_names" {
  value = sort([for vm in proxmox_virtual_environment_vm.k3s_agent : vm.name])
}

output "k3s_server_vm_ids" {
  value = { for k, vm in proxmox_virtual_environment_vm.k3s_server : k => vm.vm_id }
}

output "k3s_agent_vm_ids" {
  value = { for k, vm in proxmox_virtual_environment_vm.k3s_agent : k => vm.vm_id }
}

output "k3s_server_ips" {
  description = "IP addresses of k3s server nodes"
  value = {
    for name, vm in proxmox_virtual_environment_vm.k3s_server :
    name => local.server_ips[name]
  }
}

output "k3s_agent_ips" {
  description = "IP addresses of k3s agent nodes"
  value = {
    for name, vm in proxmox_virtual_environment_vm.k3s_agent :
    name => local.agent_ips[name]
  }
}

output "all_vm_ips" {
  description = "All VM IP addresses"
  value       = local.vm_ips
}

output "ansible_inventory" {
  description = "Ansible inventory format"
  value       = <<-EOT
[k3s_masters]
%{for name in local.server_names~}
${name} ansible_host=${local.server_ips[name]}
%{endfor~}

[k3s_agents]
%{for name in local.agent_names~}
${name} ansible_host=${local.agent_ips[name]}
%{endfor~}

[k3s_cluster:children]
k3s_masters
k3s_agents

[all:vars]
ansible_user=${var.vm_user}
ansible_ssh_private_key_file=../terraform/proxmox/keys/id_ed25519
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
  EOT
}
