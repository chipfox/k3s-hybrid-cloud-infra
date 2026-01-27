# k3s Hybrid Cloud Infrastructure

Terraform configuration for deploying k3s across Proxmox (on-premises) and AWS EKS (cloud).

## Structure

- **`terraform/proxmox/`** - Ubuntu VMs for k3s on Proxmox VE cluster
- **`terraform/aws-eks/`** - EKS cluster with managed node group on AWS

## Quick Start

Each directory has its own README with setup instructions:

1. [Proxmox k3s Infrastructure](terraform/proxmox/README.md)
2. [AWS EKS Cluster](terraform/aws-eks/README.md)
