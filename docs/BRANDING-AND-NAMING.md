# Бренд и имена в документации

## Публичное имя

**Ceitnot** (или **Ceitnot Protocol**) — имя продукта для пользователей, сайта, соцсетей и большинства текстов в `docs/`.

## Имена в коде и на блокчейне

В репозитории контракты называются **`CeitnotEngine`**, **`CeitnotUSD`**, **`CeitnotPSM`**, **`CeitnotToken`**, **`VeCeitnot`**, **`CeitnotGovernor`**, **`CeitnotTreasury`**, **`CeitnotMarketRegistry`**, **`CeitnotProxy`**, **`CeitnotRouter`** и т.д.

Токен управления в `CeitnotToken.sol`: имя **Ceitnot**, тикер **CEITNOT**. Старые деплои могли использовать другие метаданные — в UI символ берётся из контракта, с подстановкой **CEITNOT** для устаревших тикеров при необходимости.

> User-facing disclosure (recommended): **"On-chain token metadata may differ from current public branding due to legacy deployment. Verify official contract addresses before interacting."**

## Переменные окружения (актуальные)

- Фронт: `VITE_GOVERNANCE_TOKEN_ADDRESS`, `VITE_VE_TOKEN_ADDRESS`, `VITE_ENGINE_ADDRESS`, …
- Бэкенд (пример): `CEITNOT_ENGINE_ADDRESS`, `CEITNOT_REGISTRY_ADDRESS`, `GOVERNANCE_TOKEN_ADDRESS`, `FAUCET_PRIVATE_KEY`
- Скрипты деплоя в логах печатают префиксы `CEITNOT_*` для адресов.

## Как писать в доках

1. О **продукте** — **Ceitnot** / **Ceitnot Protocol**.
2. О **конкретном контракте** — имя в обратных кавычках: `` `CeitnotUSD.mint` ``.

См. также [README-GITBOOK.md](README-GITBOOK.md) и [CONTRACTS.md](CONTRACTS.md).

## FAQ (short, for website/support)

### Почему имя токена в кошельке/эксплорере может отличаться от бренда?

Часть контрактов была развернута до ребрендинга. Это не меняет адреса и логику контрактов.
Источник истины для пользователей — канонический список адресов:
[`PRODUCTION-ADDRESSES-ARBITRUM.md`](PRODUCTION-ADDRESSES-ARBITRUM.md).

### Что показывать в UI, чтобы не путать пользователей?

1. Символ токена (например, `CEITNOT`, `aUSD`).
2. Полный адрес контракта (со ссылкой на Arbiscan).
3. Короткий дисклеймер о legacy naming.
