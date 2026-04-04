# Verify all contracts from DeployFullArbitrum broadcast (chain 42161).
# Usage (PowerShell):
#   $env:ARBISCAN_API_KEY = "your_key"
#   ./script/VerifyFullArbitrum.ps1
# Optional: $env:VERIFY_ROOT = path to repo root (default: parent of script/).
$ErrorActionPreference = "Continue"
$root = if ($env:VERIFY_ROOT) { $env:VERIFY_ROOT } else { Split-Path -Parent $PSScriptRoot }
Set-Location $root

$key = $env:ARBISCAN_API_KEY
if (-not $key) { throw "Set ARBISCAN_API_KEY (Etherscan v2 / Arbiscan key)." }

$base = @(
    "--chain", "arbitrum",
    "--verifier", "etherscan",
    "--etherscan-api-key", $key,
    "--via-ir",
    "--evm-version", "cancun",
    "--watch"
)

function Invoke-Verify {
    param(
        [string]$Address,
        [string]$Contract,
        [string]$EncodedArgs = $null
    )
    Write-Host "`n=== $Contract @ $Address ===" -ForegroundColor Cyan
    if ($EncodedArgs) {
        & forge verify-contract $Address $Contract --constructor-args $EncodedArgs @base
    } else {
        & forge verify-contract $Address $Contract @base
    }
    if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: $Contract" -ForegroundColor Red; $script:verifyFailed = $true }
}

$script:verifyFailed = $false

# Addresses from broadcast/DeployFullArbitrum.s.sol/42161/run-latest.json
Invoke-Verify "0x54eb3b26220eb901349a2dfa5011e89ba62e458b" "test/mocks/MockERC20.sol:MockERC20" (cast abi-encode "constructor(string,string,uint8)" "Wrapped stETH" "wstETH" 18)
Invoke-Verify "0x91799566f1384f5d0ea847aa3720d76faa73caaa" "test/mocks/MockVault4626.sol:MockVault4626" (cast abi-encode "constructor(address,string,string)" 0x54Eb3b26220Eb901349A2dFa5011E89Ba62e458B "Ceitnot wstETH Vault" "aWstETH")
Invoke-Verify "0x7718fff145d1954b60547ed206b21284e7a648ee" "src/OracleRelay.sol:OracleRelay" (cast abi-encode "constructor(address,address,uint256)" 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612 0x0000000000000000000000000000000000000000 0)
Invoke-Verify "0xe1b1a3814c3f5f3cdfd85a63225f7d16ecdd6785" "src/CeitnotUSD.sol:CeitnotUSD" (cast abi-encode "constructor(address)" 0x05BDb3dbd872C67f17aA45c7583391d8367FA6Ed)
Invoke-Verify "0x070b9c6bdbffabefe02de23840069f15eb821c55" "src/CeitnotMarketRegistry.sol:CeitnotMarketRegistry" (cast abi-encode "constructor(address)" 0x05BDb3dbd872C67f17aA45c7583391d8367FA6Ed)
Invoke-Verify "0xabb9a8986f2ef5abf136f4902fd35e49e37f088e" "src/CeitnotEngine.sol:CeitnotEngine"
Invoke-Verify "0xd2168f8429acb4796465b07ca6ecf192d9b41619" "src/CeitnotProxy.sol:CeitnotProxy" (cast abi-encode "constructor(address,bytes)" 0xabb9A8986f2eF5abF136f4902fD35E49e37f088e 0xeb990c59000000000000000000000000e1b1a3814c3f5f3cdfd85a63225f7d16ecdd6785000000000000000000000000070b9c6bdbffabefe02de23840069f15eb821c550000000000000000000000000000000000000000000000000000000000000e10000000000000000000000000000000000000000000000000000000000002a300)
Invoke-Verify "0xcb18d815e5b686372d9494583812cd46ca869919" "src/CeitnotPSM.sol:CeitnotPSM" (cast abi-encode "constructor(address,address,address,uint16,uint16)" 0xe1b1a3814c3f5F3cDfd85a63225f7d16EcDD6785 0xaf88d065e77c8cC2239327C5EDb3A432268e5831 0x05BDb3dbd872C67f17aA45c7583391d8367FA6Ed 10 10)
Invoke-Verify "0x4f083ab27345f353e61f04988c8fefc76eacbb7d" "src/CeitnotRouter.sol:CeitnotRouter" (cast abi-encode "constructor(address,address)" 0xd2168f8429acB4796465b07Ca6ECf192d9b41619 0xe1b1a3814c3f5F3cDfd85a63225f7d16EcDD6785)
Invoke-Verify "0xeec09a4ec6fabef4587195296f2d0a4404c7a947" "src/CeitnotTreasury.sol:CeitnotTreasury" (cast abi-encode "constructor(address)" 0x05BDb3dbd872C67f17aA45c7583391d8367FA6Ed)
Invoke-Verify "0xbf6fa2c4d3c31b794417f87d1c06dc401e012e28" "src/governance/CeitnotToken.sol:CeitnotToken" (cast abi-encode "constructor(address)" 0x05BDb3dbd872C67f17aA45c7583391d8367FA6Ed)
Invoke-Verify "0x9617c423dcaaf8d029d4c547747ef020974fcca5" "src/governance/VeCeitnot.sol:VeCeitnot" (cast abi-encode "constructor(address,address,address)" 0xBF6Fa2c4D3C31B794417f87D1C06Dc401e012e28 0x05BDb3dbd872C67f17aA45c7583391d8367FA6Ed 0xe1b1a3814c3f5F3cDfd85a63225f7d16EcDD6785)
Invoke-Verify "0x14fae3f4c19a4733ea5762123b8a9131615b2d19" "lib/openzeppelin-contracts/contracts/governance/TimelockController.sol:TimelockController" (cast abi-encode "constructor(uint256,address[],address[],address)" 86400 "[0x05BDb3dBd872C67f17aA45c7583391d8367FA6Ed]" "[0x0000000000000000000000000000000000000000]" 0x05BDb3dbd872C67f17aA45c7583391d8367FA6Ed)
Invoke-Verify "0xa4d0f26cabec345034c2687467b6157cae581216" "src/governance/CeitnotGovernor.sol:CeitnotGovernor" (cast abi-encode "constructor(address,address)" 0x9617c423dCaAF8d029D4C547747EF020974fcca5 0x14Fae3f4c19a4733eA5762123B8a9131615b2d19)

if ($script:verifyFailed) {
    Write-Host "`nDone with errors - check FAILED lines above." -ForegroundColor Yellow
    exit 1
}
Write-Host "`nAll verifications submitted OK." -ForegroundColor Green
