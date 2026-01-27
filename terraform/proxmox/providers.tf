provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token

  # Set to true if you use self-signed certs (common in homelabs)
  insecure = var.proxmox_insecure

  # Required for snippet uploads (cloud-init user-data) when content_type = "snippets".
  # See: https://registry.terraform.io/providers/bpg/proxmox/latest/docs/index#ssh
  ssh {
    agent    = false
    username = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
  }
}
