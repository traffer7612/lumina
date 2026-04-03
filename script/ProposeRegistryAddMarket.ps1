# Governor.propose for AuraMarketRegistry.addMarket calldata (Arbitrum / any RPC).
# Avoids pasting a huge hex into PowerShell (use a file instead).
#
# Prereq: forge (cast). Set PRIVATE_KEY to a wallet that can create proposals (threshold / role).
#
# 1) Generate calldata (no broadcast):
#    $env:VAULT_ADDRESS = "0x..."; $env:ORACLE_ADDRESS = "0x..."
#    forge script script/PrintRegistryAddMarketCalldata.s.sol:PrintRegistryAddMarketCalldata --rpc-url $env:ARBITRUM_RPC_URL -vvv
# 2) Save the printed 0x... line to a file (one line, no spaces), e.g. addmarket.calldata.hex
# 3) Run this script (same PROPOSAL_DESCRIPTION for queue/execute later):
#    $env:PRIVATE_KEY = "0x..."
#    $env:ARBITRUM_RPC_URL = "https://arb1.arbitrum.io/rpc"
#    .\script\ProposeRegistryAddMarket.ps1 -CalldataPath .\addmarket.calldata.hex
#
# Optional env: GOVERNOR_ADDRESS, REGISTRY_ADDRESS (else read from frontend\.env VITE_*)

param(
    [Parameter(Mandatory = $true)]
    [string] $CalldataPath,
    [string] $ProposalDescription = "AIP: Add Lumina USDC market"
)

# Cursor/PS sometimes appends ";<uuid>" or duplicates ".hex" when pasting — strip it.
$CalldataPath = ($CalldataPath -split ';', 2)[0].Trim()
if ($CalldataPath -match '\.hexhex$') { $CalldataPath = $CalldataPath -replace '\.hexhex$', '.hex' }

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $repoRoot "frontend\.env"

function Read-EnvFromDotEnv {
    param([string] $Key)
    if (-not (Test-Path $envFile)) { return $null }
    $line = Get-Content $envFile | Where-Object { $_ -match "^\s*$([regex]::Escape($Key))\s*=\s*(.+)\s*$" } | Select-Object -First 1
    if (-not $line) { return $null }
    if ($line -match "^\s*$([regex]::Escape($Key))\s*=\s*(.+)\s*$") {
        return $Matches[1].Trim().Trim('"')
    }
    return $null
}

$gov = if ($env:GOVERNOR_ADDRESS) { $env:GOVERNOR_ADDRESS } else { Read-EnvFromDotEnv "VITE_GOVERNOR_ADDRESS" }
$reg = if ($env:REGISTRY_ADDRESS) { $env:REGISTRY_ADDRESS } else { Read-EnvFromDotEnv "VITE_REGISTRY_ADDRESS" }

if (-not $gov) { Write-Error "Set GOVERNOR_ADDRESS or VITE_GOVERNOR_ADDRESS in frontend/.env" }
if (-not $reg) { Write-Error "Set REGISTRY_ADDRESS or VITE_REGISTRY_ADDRESS in frontend/.env" }
if (-not $env:PRIVATE_KEY) { Write-Error "Set PRIVATE_KEY in the environment" }
$privateKey = $env:PRIVATE_KEY.Trim()
if ($privateKey -notmatch '^0x') { $privateKey = "0x$privateKey" }

$rpc = if ($env:ARBITRUM_RPC_URL) { $env:ARBITRUM_RPC_URL } else { "https://arb1.arbitrum.io/rpc" }

if (-not (Test-Path -LiteralPath $CalldataPath)) { Write-Error "CalldataPath not found: $CalldataPath" }
$fi = Get-Item -LiteralPath $CalldataPath -ErrorAction Stop
if ($fi.Length -eq 0) {
    Write-Error "Calldata file is 0 bytes - save the line from forge into $CalldataPath (Ctrl+S in editor)."
}
# Get-Content -Raw can return $null on PS 5.1 for some files; File.ReadAllText is reliable.
try {
    $raw = [System.IO.File]::ReadAllText($fi.FullName)
} catch {
    Write-Error "Cannot read calldata file: $($_.Exception.Message)"
}
if ($null -eq $raw) { $raw = "" }
$calldata = $raw.Trim().TrimStart([char]0xFEFF)
if ([string]::IsNullOrWhiteSpace($calldata)) { Write-Error "Calldata file is empty after trim: $CalldataPath" }
if ($calldata -notmatch '^0x[0-9a-fA-F]+$') { Write-Error "Calldata file must be one line 0x..." }

Write-Host "Governor:  $gov"
Write-Host "Registry:  $reg"
Write-Host "RPC:       $rpc"
Write-Host ('Calldata:  ' + $calldata.Substring(0, [Math]::Min(20, $calldata.Length)) + '... ' + $calldata.Length + ' chars')
Write-Host "Description: $ProposalDescription"
Write-Host ""

$castArgs = @(
    "send", $gov,
    'propose(address[],uint256[],bytes[],string)',
    "[$reg]", "[0]", "[$calldata]", $ProposalDescription,
    "--rpc-url", $rpc,
    "--private-key", $privateKey
)

& cast @castArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$descHash = (& cast keccak $ProposalDescription).Trim()
Write-Host ""
Write-Host "Next (after voting succeeds): use the SAME description and calldata."
Write-Host "Description hash (bytes32): $descHash"
Write-Host ""
# Full queue/execute lines (PS 5.1 cannot reliably parse long cast hints with address[] in source).
$hintPath = Join-Path $repoRoot "queue-execute-cast-hint.txt"
$dq = [char]34
$sb = New-Object System.Text.StringBuilder
foreach ($sig in @('queue(address[],uint256[],bytes[],bytes32)', 'execute(address[],uint256[],bytes[],bytes32)')) {
    [void]$sb.AppendLine(('cast send {0} {1}{2}{1} {1}[{3}]{1} {1}[0]{1} {1}[{4}]{1} {5} --rpc-url {1}{6}{1} --private-key $env:PRIVATE_KEY' -f $gov, $dq, $sig, $reg, $calldata, $descHash, $rpc))
    [void]$sb.AppendLine('')
}
[System.IO.File]::WriteAllText($hintPath, $sb.ToString())
Write-Host "Queue / Execute cast hints written to: $hintPath"
