# HAProxy Integration Guide

This document describes how to integrate the k3s cluster with your existing HAProxy router setup, matching your Docker VM architecture pattern.

## Architecture Pattern

**Docker VM Pattern (Current):**
```
HAProxy → 10.0.0.X (Docker VM, single IP)
  ├─ :2283  → Immich
  ├─ :5055  → Overseerr  
  ├─ :7575  → Homarr
  ├─ :8183  → Tautulli
  └─ :8282  → SABnzbd
```

**k3s Cluster Pattern (New):**
```
HAProxy → 10.0.0.230, 10.0.0.231, 10.0.0.232 (k3s servers, 3 IPs for HA)
  ├─ :30284 → Argo CD (HTTPS)
  ├─ :32283 → Immich (future)
  ├─ :35055 → Overseerr (future)
  └─ etc.
```

**Key Differences:**
- **Single IP → Multiple IPs**: HAProxy backend pool contains 3 server IPs instead of 1
- **NodePort Range**: k3s uses ports 30000-32767 (configurable) instead of low ports
- **Automatic HA**: If one k3s node fails, HAProxy routes to the other 2 automatically

## Current Deployment

### Argo CD Exposure

**Service:** argocd-server  
**Type:** NodePort  
**HTTPS Port:** 30284 (on all k3s server nodes)  
**Accessible at:**
- https://10.0.0.230:30284
- https://10.0.0.231:30284
- https://10.0.0.232:30284

**Credentials:**
- Username: `chipfox`
- Password: Same as vm_password from Terraform variables

## HAProxy Configuration

### Backend Configuration for Argo CD

Add to your HAProxy configuration:

```haproxy
# Argo CD Backend
backend argocd_backend
    mode http
    balance roundrobin
    option httpchk GET /healthz
    http-check expect status 200
    server k3st-1 10.0.0.230:30284 check ssl verify none
    server k3st-2 10.0.0.231:30284 check ssl verify none
    server k3st-3 10.0.0.232:30284 check ssl verify none
```

### Frontend Configuration (HTTPS with SNI)

```haproxy
# HTTPS Frontend with SNI routing
frontend https_frontend
    bind *:443 ssl crt /etc/haproxy/certs/chipfoxx.com.pem
    mode http
    
    # Argo CD routing
    acl is_argocd hdr(host) -i argocd.chipfoxx.com
    use_backend argocd_backend if is_argocd
    
    # Future services (examples)
    # acl is_immich hdr(host) -i immich.chipfoxx.com
    # use_backend immich_backend if is_immich
```

### Alternative: Port-Based Routing (Like Docker VM)

If you prefer port-based routing instead of hostname-based:

```haproxy
# Port 30284 → Argo CD (transparent proxy)
frontend argocd_port
    bind *:30284
    mode tcp
    default_backend argocd_backend

backend argocd_backend
    mode tcp
    balance roundrobin
    option tcp-check
    server k3st-1 10.0.0.230:30284 check
    server k3st-2 10.0.0.231:30284 check
    server k3st-3 10.0.0.232:30284 check
```

**Access:** https://`router-ip`:30284 (HAProxy transparently proxies to k3s)

## NodePort Range Configuration

By default, k3s uses ports **30000-32767** for NodePort services. This avoids conflicts with common application ports but differs from your Docker setup.

### Options to Match Docker Ports

**Option 1: Expand NodePort Range (Requires k3s reconfiguration)**

Not recommended - conflicts with host services.

**Option 2: Use Port Translation in HAProxy (Recommended)**

HAProxy frontend listens on familiar port, backends use NodePort:

```haproxy
# Frontend: Familiar Docker port
frontend immich_frontend
    bind *:2283
    mode http
    default_backend immich_backend

# Backend: k3s NodePort
backend immich_backend
    mode http
    balance roundrobin
    server k3st-1 10.0.0.230:32283 check
    server k3st-2 10.0.0.231:32283 check
    server k3st-3 10.0.0.232:32283 check
```

**Result:** Users access `http://router:2283` (same as Docker), HAProxy routes to `10.0.0.230-232:32283` (k3s NodePort)

## Service Port Mapping Guide

When migrating services from Docker to k3s, use this mapping:

| Service | Docker Port | k3s NodePort | HAProxy Frontend |
|---------|-------------|--------------|------------------|
| Argo CD | N/A | 30284 | 443 (SNI: argocd.chipfoxx.com) |
| Immich | 2283 | 32283 | 2283 (port translation) |
| Overseerr | 5055 | 35055 | 5055 (port translation) |
| Homarr | 7575 | 37575 | 7575 (port translation) |
| Tautulli | 8183 | 38183 | 8183 (port translation) |
| SABnzbd | 8282 | 38282 | 8282 (port translation) |
| Jellyfin | 8096 | 38096 | 8096 (port translation) |
| Radarr | 7879 | 37879 | 7879 (port translation) |
| Prowlarr | 9696 | 39696 | 9696 (port translation) |

**Pattern:** k3s NodePort = 30000 + Docker Port (where possible)

## Complete HAProxy Configuration Template

```haproxy
#---------------------------------------------------------------------
# k3s Cluster Integration
#---------------------------------------------------------------------

# Define k3s server nodes
backend k3s_servers_common
    balance roundrobin
    option tcp-check
    server k3st-1 10.0.0.230 check
    server k3st-2 10.0.0.231 check
    server k3st-3 10.0.0.232 check

#---------------------------------------------------------------------
# Argo CD (HTTPS with SNI)
#---------------------------------------------------------------------
backend argocd_backend
    mode http
    balance roundrobin
    option httpchk GET /healthz
    http-check expect status 200
    server k3st-1 10.0.0.230:30284 check ssl verify none
    server k3st-2 10.0.0.231:30284 check ssl verify none
    server k3st-3 10.0.0.232:30284 check ssl verify none

frontend https_frontend
    bind *:443 ssl crt /etc/haproxy/certs/chipfoxx.com.pem
    mode http
    acl is_argocd hdr(host) -i argocd.chipfoxx.com
    use_backend argocd_backend if is_argocd

#---------------------------------------------------------------------
# Future Service Template (Port Translation Pattern)
#---------------------------------------------------------------------
# Uncomment and customize as you migrate services

# frontend immich_frontend
#     bind *:2283
#     mode http
#     default_backend immich_backend
# 
# backend immich_backend
#     mode http
#     balance roundrobin
#     option httpchk GET /api/server-info/ping
#     server k3st-1 10.0.0.230:32283 check
#     server k3st-2 10.0.0.231:32283 check
#     server k3st-3 10.0.0.232:32283 check
```

## Verifying NodePort Services

### Check Service Exposure

```bash
# From k3s node
ssh chipfox@10.0.0.230
sudo kubectl get svc -n argocd argocd-server

# Expected output shows:
# TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
# NodePort    10.43.X.X       <none>        80:30283/TCP,443:30284/TCP
```

### Test from HAProxy Router

```bash
# From your HAProxy router/machine
curl -k https://10.0.0.230:30284/healthz
curl -k https://10.0.0.231:30284/healthz
curl -k https://10.0.0.232:30284/healthz

# All should return: OK
```

## Migration Pattern for Each Service

When migrating a service from Docker to k3s:

### 1. Deploy Service with NodePort

```yaml
apiVersion: v1
kind: Service
metadata:
  name: immich
  namespace: immich
spec:
  type: NodePort
  ports:
    - name: http
      port: 2283
      targetPort: 2283
      nodePort: 32283  # Static port
  selector:
    app: immich
```

### 2. Add HAProxy Configuration

```haproxy
frontend immich_frontend
    bind *:2283
    mode http
    default_backend immich_backend

backend immich_backend
    mode http
    balance roundrobin
    server k3st-1 10.0.0.230:32283 check
    server k3st-2 10.0.0.231:32283 check
    server k3st-3 10.0.0.232:32283 check
```

### 3. Test Before DNS Cutover

```bash
# Access via HAProxy IP
curl http://haproxy-ip:2283

# Should reach Immich on k3s
```

### 4. Update DNS and Stop Docker

```bash
# Update DNS to point to HAProxy IP (if using hostname)
# Or keep same HAProxy IP (if using port-based routing)

# Stop Docker container
docker stop immich
```

## Benefits of This Approach

✅ **Familiar Architecture**: Same pattern as Docker VM  
✅ **No New Dependencies**: No MetalLB, Istio, or service mesh needed  
✅ **Built-in HA**: NodePort + HAProxy provides automatic failover  
✅ **Simple Migration**: One service at a time, same ports users know  
✅ **Rollback**: Switch HAProxy back to Docker VM if needed  

## Next Steps for Service Migration

1. **Verify Argo CD accessible via HAProxy** at argocd.chipfoxx.com
2. **Migrate services following your [[Docker Container List]] priorities**
3. **Use NodePort pattern** for each service (see Migration Pattern above)
4. **Update HAProxy config** as each service is migrated
5. **Test hybrid operation** (some on Docker VM, some on k3s) before full cutover

## Notes

- **NodePort reserves port cluster-wide**: Once you use port 32283, no other service can use it
- **Port exhaustion unlikely**: 30000-32767 gives you 2767 available ports (way more than your 18 services)
- **Agent nodes also expose NodePort**: Ports are accessible on all 7 nodes, but HAProxy should target servers (10.0.0.230-232) for control-plane proximity
- **No intra-service conflicts**: Each k8s service gets its own NodePort, can't conflict like Docker port bindings

## When You Add AWS EKS

When integrating AWS EKS, you'll likely want:
- **Local k3s**: Use NodePort pattern (HAProxy backend)
- **AWS EKS**: Use AWS Load Balancer (NLB/ALB)
- **Argo CD**: Runs on local k3s, manages both clusters
- **HAProxy**: Only routes to local k3s services, AWS services use their own LBs
