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
