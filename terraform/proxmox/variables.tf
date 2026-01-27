variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, e.g. https://pve1:8006"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token, e.g. user@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for the Proxmox API endpoint"
  type        = bool
  default     = true
}

variable "proxmox_ssh_username" {
  description = "SSH username for the Proxmox node (used for snippet uploads)"
  type        = string
  default     = "root"
}

variable "proxmox_ssh_password" {
  description = "SSH password for the Proxmox node (used for snippet uploads). Prefer using TF_VAR_proxmox_ssh_password env var."
  type        = string
  sensitive   = true
}

variable "proxmox_nodes" {
  description = "Proxmox node names to spread VMs across (round-robin), e.g. [\"pve1\", \"pve2\"]"
  type        = list(string)
}

variable "snippets_node_name" {
  description = "Node name to upload cloud-init snippet files to (since you're using shared storage, any node works)"
  type        = string
}

variable "snippets_datastore_id" {
  description = "Datastore ID with 'Snippets' content type enabled"
  type        = string
  default     = "local"
}

variable "vm_pool_id" {
  description = "Optional Proxmox pool id to place created VMs into"
  type        = string
  default     = null
}

variable "vm_tags" {
  description = "Tags to apply to created VMs"
  type        = list(string)
  default     = ["terraform", "k3st"]
}

variable "template_vm_id" {
  description = "VMID of an existing Ubuntu 25.10 cloud-init template VM in Proxmox"
  type        = number
}

variable "template_node_name" {
  description = "Node that currently hosts the template VM (only needed if different from target node)"
  type        = string
  default     = null
}

variable "clone_full" {
  description = "Full clone (true) or linked clone (false)"
  type        = bool
  default     = true
}

variable "vm_datastore_id" {
  description = "Target datastore for cloned disks when cloning across nodes"
  type        = string
  default     = "local-lvm"
}

variable "vm_bridge" {
  description = "Bridge to attach the VM network interface to"
  type        = string
  default     = "vmbr0"
}

variable "vm_user" {
  description = "Default user account created by cloud-init"
  type        = string
  default     = "ubuntu"
}

variable "vm_ssh_public_key" {
  description = "Path to SSH public key file (relative or absolute)"
  type        = string
}

variable "k3s_server_count" {
  description = "How many k3s server (control-plane) VMs to create (k3s-1..k3s-N)"
  type        = number
  default     = 3
}

variable "k3s_agent_count" {
  description = "How many k3s agent VMs to create (k3s-a1..k3s-aM)"
  type        = number
  default     = 3
}

variable "k3s_server_cpu_cores" {
  description = "CPU cores for k3s server VMs"
  type        = number
  default     = 2
}

variable "k3s_server_memory_mb" {
  description = "Memory in MB for k3s server VMs"
  type        = number
  default     = 4096
}

variable "k3s_agent_cpu_cores" {
  description = "CPU cores for k3s agent VMs"
  type        = number
  default     = 2
}

variable "k3s_agent_memory_mb" {
  description = "Memory in MB for k3s agent VMs"
  type        = number
  default     = 4096
}
