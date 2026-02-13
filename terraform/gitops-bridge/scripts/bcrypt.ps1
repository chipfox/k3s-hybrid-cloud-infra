# PowerShell script to generate bcrypt hash using argocd CLI
# Usage: powershell -File bcrypt.ps1 -Password "plaintext"
param(
    [Parameter(Mandatory=$true)]
    [string]$Password
)

# Set error handling
$ErrorActionPreference = "Stop"

try {
    # Check if argocd CLI is available locally
    $argocdPath = Get-Command argocd -ErrorAction SilentlyContinue
    
    if ($argocdPath) {
        # Use local argocd CLI
        $hash = & argocd account bcrypt --password $Password 2>&1 | Select-Object -Last 1
    } else {
        # Fallback: Use kubectl to exec into argocd pod
        $kubeconfig = "$PSScriptRoot/../../../k3s-ansible/kubeconfig"
        
        if (-not (Test-Path $kubeconfig)) {
            throw "Kubeconfig not found at $kubeconfig"
        }
        
        # Find argocd server pod
        $pod = & kubectl --kubeconfig=$kubeconfig get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}' 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to find argocd server pod: $pod"
        }
        
        # Generate bcrypt hash inside pod
        $hash = & kubectl --kubeconfig=$kubeconfig exec -n argocd $pod -- argocd account bcrypt --password $Password 2>&1 | Select-Object -Last 1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to generate bcrypt hash: $hash"
        }
    }
    
    # Output JSON for Terraform external data source
    $output = @{
        hash = $hash.Trim()
    } | ConvertTo-Json -Compress
    
    Write-Output $output
} catch {
    # Output error as JSON
    $errorOutput = @{
        error = $_.Exception.Message
    } | ConvertTo-Json -Compress
    
    Write-Error $errorOutput
    exit 1
}
