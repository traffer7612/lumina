# Команды для личного теста комиссий (Arbitrum)

Этот гайд для личного теста дохода, где комиссии протокола выводятся на ваш EOA.

Важно:
- Админом является `Timelock`, поэтому вывод делается через governance-процесс: `propose -> vote -> queue -> execute`.
- Кошелек, который создает proposal, должен проходить порог `Governor` (достаточно `veCEITNOT` голосов).

## 0) Фиксированные адреса в этом гайде

- Governor: `0xa4d0f26cabec345034c2687467b6157cae581216`
- Timelock: `0x14fae3f4c19a4733ea5762123b8a9131615b2d19`
- PSM: `0xcb18d815e5b686372d9494583812cd46ca869919`
- Engine: `0xd2168f8429acb4796465b07ca6ecf192d9b41619`
- USDC (Arbitrum): `0xaf88d065e77c8cc2239327c5edb3a432268e5831`
- Личный EOA-получатель (пример): `0x6579aC68b40dB4f7DE470db7b62cA1A33fCAa2Ec`

## 1) Подготовка сессии (PowerShell)

```powershell
cd F:\aura
$env:ARBITRUM_RPC_URL="https://arb1.arbitrum.io/rpc"
# задается один раз на сессию терминала:
# $env:PRIVATE_KEY="0xYOUR_PRIVATE_KEY"
```

## 2) Необязательные sanity-check проверки

Проверить, кто сейчас admin (должен быть Timelock):

```powershell
cast call 0xcb18d815e5b686372d9494583812cd46ca869919 "admin()(address)" --rpc-url $env:ARBITRUM_RPC_URL
cast call 0xd2168f8429acb4796465b07ca6ecf192d9b41619 "admin()(address)" --rpc-url $env:ARBITRUM_RPC_URL
```

Проверить доступные резервы комиссий PSM до proposal:

```powershell
cast call 0xcb18d815e5b686372d9494583812cd46ca869919 "feeReserves()(uint256)" --rpc-url $env:ARBITRUM_RPC_URL
```

Проверить ваш баланс USDC до execute:

```powershell
cast call 0xaf88d065e77c8cc2239327c5edb3a432268e5831 "balanceOf(address)(uint256)" 0x6579aC68b40dB4f7DE470db7b62cA1A33fCAa2Ec --rpc-url $env:ARBITRUM_RPC_URL
```

---

## 3) Сценарий A (рекомендуется начать с него): вывод комиссий PSM на ваш EOA

### 3.1 Создать proposal

`amount` указывается в raw-единицах USDC (6 знаков):
- `1000000` = 1 USDC
- `5000000` = 5 USDC

```powershell
$to="0x6579aC68b40dB4f7DE470db7b62cA1A33fCAa2Ec"
$amount="1000000"
$desc="AIP: Personal fee test - withdraw PSM fees to 0x6579"

$calldata = cast calldata "withdrawFeeReserves(address,uint256)" $to $amount

cast send 0xa4d0f26cabec345034c2687467b6157cae581216 "propose(address[],uint256[],bytes[],string)" "[0xcb18d815e5b686372d9494583812cd46ca869919]" "[0]" "[$calldata]" $desc --rpc-url $env:ARBITRUM_RPC_URL --private-key $env:PRIVATE_KEY
```

Сохраните из логов транзакции:
- `proposalId` (decimal)

### 3.2 Дождаться состояния Active и проголосовать

Значения `support`:
- `0` = Against
- `1` = For
- `2` = Abstain

```powershell
$proposalId="PUT_DECIMAL_PROPOSAL_ID_HERE"
cast send 0xa4d0f26cabec345034c2687467b6157cae581216 "castVote(uint256,uint8)" $proposalId 1 --rpc-url $env:ARBITRUM_RPC_URL --private-key $env:PRIVATE_KEY
```

Проверить состояние proposal:

```powershell
cast call 0xa4d0f26cabec345034c2687467b6157cae581216 "state(uint256)(uint8)" $proposalId --rpc-url $env:ARBITRUM_RPC_URL
```

Карта состояний:
- `0 Pending`
- `1 Active`
- `3 Defeated`
- `4 Succeeded`
- `5 Queued`
- `7 Executed`

### 3.3 Queue (когда состояние `Succeeded = 4`)

```powershell
$to="0x6579aC68b40dB4f7DE470db7b62cA1A33fCAa2Ec"
$amount="1000000"
$desc="AIP: Personal fee test - withdraw PSM fees to 0x6579"
$descriptionHash = cast keccak $desc
$calldata = cast calldata "withdrawFeeReserves(address,uint256)" $to $amount

cast send 0xa4d0f26cabec345034c2687467b6157cae581216 "queue(address[],uint256[],bytes[],bytes32)" "[0xcb18d815e5b686372d9494583812cd46ca869919]" "[0]" "[$calldata]" $descriptionHash --rpc-url $env:ARBITRUM_RPC_URL --private-key $env:PRIVATE_KEY
```

### 3.4 Execute (после задержки Timelock)

```powershell
$to="0x6579aC68b40dB4f7DE470db7b62cA1A33fCAa2Ec"
$amount="1000000"
$desc="AIP: Personal fee test - withdraw PSM fees to 0x6579"
$descriptionHash = cast keccak $desc
$calldata = cast calldata "withdrawFeeReserves(address,uint256)" $to $amount

cast send 0xa4d0f26cabec345034c2687467b6157cae581216 "execute(address[],uint256[],bytes[],bytes32)" "[0xcb18d815e5b686372d9494583812cd46ca869919]" "[0]" "[$calldata]" $descriptionHash --rpc-url $env:ARBITRUM_RPC_URL --private-key $env:PRIVATE_KEY
```

### 3.5 Проверка после execute

```powershell
cast call 0xaf88d065e77c8cc2239327c5edb3a432268e5831 "balanceOf(address)(uint256)" 0x6579aC68b40dB4f7DE470db7b62cA1A33fCAa2Ec --rpc-url $env:ARBITRUM_RPC_URL
cast call 0xcb18d815e5b686372d9494583812cd46ca869919 "feeReserves()(uint256)" --rpc-url $env:ARBITRUM_RPC_URL
```

---

## 4) Сценарий B (опционально): вывод резервов Engine на ваш EOA

Это резерв рынка в debt token (`aUSD`), а не комиссии PSM в USDC.

```powershell
$marketId="1"
$to="0x6579aC68b40dB4f7DE470db7b62cA1A33fCAa2Ec"
$amount="1000000000000000000"   # 1 aUSD (18 decimals)
$desc="AIP: Personal fee test - withdraw Engine reserves market 1 to 0x6579"

$calldata = cast calldata "withdrawReserves(uint256,uint256,address)" $marketId $amount $to

cast send 0xa4d0f26cabec345034c2687467b6157cae581216 "propose(address[],uint256[],bytes[],string)" "[0xd2168f8429acb4796465b07ca6ecf192d9b41619]" "[0]" "[$calldata]" $desc --rpc-url $env:ARBITRUM_RPC_URL --private-key $env:PRIVATE_KEY
```

Шаблон `queue/execute` тот же, что и в Сценарии A (меняется только `target` и calldata на Engine).

## 5) Частые ошибки

- `--rpc-url ... none was supplied`: задайте `$env:ARBITRUM_RPC_URL` в этом терминале.
- `GovernorInsufficientProposerVotes`: у вашего кошелька недостаточно `veCEITNOT` голосов.
- Proposal в неожиданном состоянии: сначала проверьте `votingDelay`, `votingPeriod` и `timelock delay`.
