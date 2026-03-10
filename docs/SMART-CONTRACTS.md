# Смарт-контракты Lumina (адреса)

Ниже приведены **адреса контрактов** для тестнета Sepolia (chainId 11155111). Для Arbitrum, Base или mainnet адреса задаются через переменные окружения при деплое и в конфиге фронта/бэкенда.

---

## Sepolia (тестнет)

| Контракт / назначение | Адрес |
|------------------------|--------|
| **Engine (Proxy)** | `0x53F2B95E1A97f95Ec35F353CdE3B05e0d1b64e04` |
| **MarketRegistry** | `0x05a585117DF7a0b909F611cC40aFd3b04dCf7A12` |
| **LUMINA (Governance token)** | `0xE023824b3160631466f2d3899D7A58E9747AF935` |
| **veLUMINA** | `0xe07027D141b74BcFeb2cfe6b658D7fedD0E5448a` |
| **aUSD (CDP stablecoin)** | `0x6a186ed7eB0046Ea18867EdA863A6F77adE2610F` |
| **PSM** | `0xde5a53134456c5b3bc0e23be92c6fc75c982985c` |
| **USDC (тестнет)** | `0x6B0e4E0e03B5a17079443fcc082AbF4092fEa4F6` |

Фронт и бэкенд берут адреса движка и реестра из переменных `VITE_ENGINE_ADDRESS`, `VITE_REGISTRY_ADDRESS`, `AURA_ENGINE_ADDRESS` и т.д. (см. README и docs/DEPLOY.md).

---

## Основные контракты (роль)

| Название в коде | Роль |
|-----------------|------|
| Engine (AuraEngine) | Логика: депозит/вывод коллатерала, займ/погашение, ликвидации, harvest, пауза. |
| Proxy (AuraProxy) | UUPS-прокси; пользователи вызывают этот адрес. |
| MarketRegistry | Реестр рынков: vault, оракул, LTV, пороги ликвидации, кэпы. |
| OracleRelay / OracleRelayV2 | Цена коллатерала (Chainlink + fallback / median). |
| LUMINA / veLUMINA | Governance и vote-escrow. |
| aUSD / PSM | CDP-стейблкоин и обмен 1:1 с USDC. |

Адреса для других сетей публикуются в конфиге приложения и в репозитории после деплоя (например в `frontend/.env.example` или в документации на docs.lumina.finance).
