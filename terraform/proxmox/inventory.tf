# Write Ansible inventory to file
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    server_names = local.server_names
    server_ips   = local.server_ips
    agent_names  = local.agent_names
    agent_ips    = local.agent_ips
    ssh_key_path = var.vm_ssh_public_key
    vm_user      = var.vm_user
  })
  filename        = "${path.module}/../../k3s-ansible/inventory.ini"
  file_permission = "0644"
}
