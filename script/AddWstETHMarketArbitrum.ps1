# Deploy OZ wstETH vault + OracleRelay + addMarket on existing CeitnotMarketRegistry (Arbitrum One).
# Requires: forge, ETH on Arbitrum for gas, REGISTRY admin key in PRIVATE_KEY (or use --ledger etc. manually).

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $repoRoot "frontend\.env"

if (-not $env:REGISTRY_ADDRESS -and (Test-Path $envFile)) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*VITE_REGISTRY_ADDRESS\s*=\s*(.+)\s*$') {
            $env:REGISTRY_ADDRESS = $Matches[1].Trim().Trim('"')
        }
    }
}

if (-not $env:REGISTRY_ADDRESS) {
    Write-Error "Set REGISTRY_ADDRESS or add VITE_REGISTRY_ADDRESS to frontend/.env"
}

$rpc = if ($env:ARBITRUM_RPC_URL) { $env:ARBITRUM_RPC_URL } else { "https://arb1.arbitrum.io/rpc" }

Write-Host "REGISTRY_ADDRESS=$($env:REGISTRY_ADDRESS)"
Write-Host "RPC=$rpc"

# forge script does not reliably use inherited PRIVATE_KEY for --broadcast; pass flag explicitly
# or addMarket reverts with Registry__Unauthorized (wrong msg.sender vs registry.admin()).
$forgeArgs = @(
    "script", "script/AddWstETHMarketArbitrum.s.sol:AddWstETHMarketArbitrum",
    "--rpc-url", $rpc,
    "--broadcast",
    "-vvv"
)
if ($env:PRIVATE_KEY) {
    $forgeArgs += @("--private-key", $env:PRIVATE_KEY.Trim())
    Write-Host "Using --private-key (address should match registry admin on Arbiscan)."
} else {
    Write-Warning "PRIVATE_KEY not set; forge may use wrong signer -> Registry__Unauthorized on addMarket. Set `$env:PRIVATE_KEY or add --ledger/--account to this script."
}

Write-Host "Running forge script..."

& forge @forgeArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Done. Copy VAULT and ORACLE from the log into frontend/.env if you want local reference variables."
