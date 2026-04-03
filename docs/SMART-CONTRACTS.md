# Смарт-контракты Ceitnot (адреса)

Ниже приведены **адреса контрактов** для тестнета Sepolia (chainId 11155111). Для Arbitrum, Base или mainnet адреса задаются через переменные окружения при деплое и в конфиге фронта/бэкенда.

Имена в ссылках на Etherscan (**`CeitnotEngine`**, **`CeitnotProxy`**, …) — как в Solidity; публичный бренд протокола — **Ceitnot**. См. [BRANDING-AND-NAMING.md](BRANDING-AND-NAMING.md).

---

## Sepolia (тестнет)

| Контракт / назначение | Адрес |
|------------------------|--------|
| **Engine (Proxy)** | `0x53F2B95E1A97f95Ec35F353CdE3B05e0d1b64e04` |
| **MarketRegistry** | `0x05a585117DF7a0b909F611cC40aFd3b04dCf7A12` |
| **CEITNOT (Governance token)** | `0xE023824b3160631466f2d3899D7A58E9747AF935` |
| **veCEITNOT** | `0xe07027D141b74BcFeb2cfe6b658D7fedD0E5448a` |
| **aUSD (CDP stablecoin)** | `0x6a186ed7eB0046Ea18867EdA863A6F77adE2610F` |
| **PSM** | `0xde5a53134456c5b3bc0e23be92c6fc75c982985c` |
| **USDC (тестнет)** | `0x6B0e4E0e03B5a17079443fcc082AbF4092fEa4F6` |

### Верификация на Sepolia Etherscan

Проверка через API v2 (`contract/getsourcecode`, chainId `11155111`). Статус на момент последней проверки:

| Адрес из таблицы | Контракт на Etherscan | Верифицирован |
|------------------|------------------------|---------------|
| Engine (Proxy) | [CeitnotProxy](https://sepolia.etherscan.io/address/0x53F2B95E1A97f95Ec35F353CdE3B05e0d1b64e04#code) | Да |
| — (implementation) | [CeitnotEngine](https://sepolia.etherscan.io/address/0x86a2d24f8502545c6c7944617faebe7c7e251cfd#code) | Да |
| MarketRegistry | [реестр](https://sepolia.etherscan.io/address/0x05a585117DF7a0b909F611cC40aFd3b04dCf7A12#code) | **Нет** — байткод деплоя не совпадает с текущим `CeitnotMarketRegistry.sol` в репозитории (скорее всего деплой с более старой версии исходников / другого `MarketConfig`). Верифицировать можно только из **того же коммита и настроек компилятора**, с которых шёл деплой, либо вручную через Standard JSON с точным артефактом `out/`. |
| CEITNOT (токен) | [CeitnotToken](https://sepolia.etherscan.io/address/0xE023824b3160631466f2d3899D7A58E9747AF935#code) | Да |
| veCEITNOT | [VeCeitnot](https://sepolia.etherscan.io/address/0xe07027D141b74BcFeb2cfe6b658D7fedD0E5448a#code) | Да |
| aUSD | [CeitnotUSD](https://sepolia.etherscan.io/address/0x6a186ed7eB0046Ea18867EdA863A6F77adE2610F#code) | Да |
| PSM | [CeitnotPSM](https://sepolia.etherscan.io/address/0xde5a53134456c5b3bc0e23be92c6fc75c982985c#code) | Да |
| USDC (mock) | [MockERC20](https://sepolia.etherscan.io/address/0x6B0e4E0e03B5a17079443fcc082AbF4092fEa4F6#code) | Да |

API-ключ Etherscan не хранить в репозитории; задавать через переменную окружения `ETHERSCAN_API_KEY` при вызове `forge verify-contract`.

### Последние рынки Sepolia (Vault + Oracle из реестра)

Адреса взяты из `MarketRegistry.getMarket(marketId)` на Sepolia (реестр `0x05a585117DF7a0b909F611cC40aFd3b04dCf7A12`):

| Market ID | Vault Address (ERC-4626) | Oracle Address |
|-----------|--------------------------|-----------------|
| 0 | `0x402dE7c0469574FCFEAE0361D15B8E32d0EcEeCd` | `0x2892a56837C71E753F90882a4e6599E390A89218` |
| 1 | `0x4cDb4b1e1DAf3a0B4Da7917319F86F752D46838E` | `0xCdE9fdc1291BF74b5b3F7AF4e19cab89A0bBD541` |

Для новых маркетов в админке (Create New Market) подставляй эти форматы: **Vault** — ERC-4626 с `convertToAssets`, **Oracle** — контракт с `getLatestPrice()`. Как получить актуальные адреса: `cast call REGISTRY "getMarket(uint256)(address,address)" 0 --rpc-url https://ethereum-sepolia.publicnode.com` (подставь `0` или `1` и свой RPC).

---

Фронт и бэкенд берут адреса движка и реестра из переменных `VITE_ENGINE_ADDRESS`, `VITE_REGISTRY_ADDRESS`, `CEITNOT_ENGINE_ADDRESS` и т.д. (см. README и docs/DEPLOY.md).

---

## Основные контракты (роль)

| Название в коде | Роль |
|-----------------|------|
| `CeitnotEngine` | Движок Ceitnot: депозит/вывод коллатерала, займ/погашение, ликвидации, harvest, пауза. |
| `CeitnotProxy` | UUPS-прокси движка Ceitnot; пользователи вызывают этот адрес. |
| MarketRegistry | Реестр рынков: vault, оракул, LTV, пороги ликвидации, кэпы. |
| OracleRelay / OracleRelayV2 | Цена коллатерала (Chainlink + fallback / median). |
| CEITNOT / veCEITNOT | Governance и vote-escrow. |
| aUSD / PSM | CDP-стейблкоин и обмен 1:1 с USDC. |

Адреса для других сетей публикуются в конфиге приложения и в репозитории после деплоя (например в `frontend/.env.example` или в документации на docs.ceitnot.finance).
