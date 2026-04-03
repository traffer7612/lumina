# Create New Market — что вводить в админке

В админке Ceitnot (Admin → Create New Market) нужно указать **Vault Address** и **Oracle Address**, а также параметры риска. Кратко, что это и откуда брать адреса.

---

## Vault Address (ERC-4626)

**Что это:** контракт, чьи **доли (shares)** пользователи вносят как коллатерал. Движок вызывает `convertToAssets(shares)` для оценки залога.

**Требование:** контракт должен реализовывать **ERC-4626** — минимум:

- `convertToAssets(uint256 shares) view returns (uint256 assets)`  
- при вызове `convertToAssets(1e18)` не ревертить (реестр при добавлении маркета проверяет это).

**Примеры:**

| Сеть       | Коллатерал | Vault Address (пример) |
|------------|------------|-------------------------|
| Arbitrum   | wstETH      | `0x5979D7b546E38E414F7E9822514be443A4800529` |
| Base       | wstETH / другой ERC-4626 | из доки протокола (Lido, Rocket Pool и т.д.) |
| Sepolia    | тестовый vault | из скрипта деплоя или свой MockVault4626 |

**Где взять адрес:** документация протокола (Lido, Rocket Pool, Yearn и т.д.) → раздел «Contract addresses» / «Smart contracts» → выбери сеть и скопируй адрес vault’а (ERC-4626). На Arbitrum для wstETH — см. [ARBITRUM-COLLATERAL-COMMANDS.md](ARBITRUM-COLLATERAL-COMMANDS.md).

---

## Oracle Address

**Что это:** контракт, который отдаёт **цену коллатерала** в формате, понятном движку. Нужен, чтобы считать LTV и ликвидации.

**Требование:** контракт должен реализовывать **IOracleRelay**:

- `getLatestPrice() view returns (uint256 value, uint256 timestamp)`  
- `value` — цена за 1e18 единиц коллатерала (в тех же decimals, что и долговой токен, обычно 1e18 WAD); **не ноль**.  
- при вызове `getLatestPrice()` не ревертить (реестр при добавлении маркета проверяет `value != 0`).

Обычно это не «сырой» Chainlink-агрегатор, а **адаптер** (OracleRelay в нашем коде), который читает Chainlink и приводит цену к 1e18. Для каждого нового коллатерала (новый vault) нужен свой оракул/адаптер под фид цены этого актива (например stETH/USD, rETH/USD).

**Примеры:**

- В деплое на Arbitrum используется наш `OracleRelay` с Chainlink ETH/USD (или stETH/USD) — в админке указываешь адрес **этого** контракта `OracleRelay`, а не адрес агрегатора Chainlink.
- Для второго маркета (другой vault, например rETH) — деплоишь второй `OracleRelay` с фидом rETH/USD и его адрес указываешь как Oracle Address.

---

## Остальные поля Create New Market

- **LTV (%)** — макс. отношение долга к стоимости залога (например 80).
- **Liq. Threshold (%)** — порог ликвидации, должен быть **≥ LTV** (например 85).
- **Liq. Penalty (%)** — штраф при ликвидации (например 5).
- **Supply Cap / Borrow Cap** — лимиты в токенах (0 = без лимита).
- **Isolated Mode** — изолированный маркет; при включении задаётся **Isolated Borrow Cap**.

Подробнее про параметры и контракт: [CONTRACTS.md](CONTRACTS.md) (`CeitnotMarketRegistry`, `addMarket`).

---

## Кратко

| Поле              | Что подставить |
|-------------------|----------------|
| **Vault Address** | Адрес ERC-4626 vault’а (например wstETH на Arbitrum: `0x5979...0529`). Должен иметь `convertToAssets`. |
| **Oracle Address**| Адрес контракта с `getLatestPrice() returns (value, timestamp)`, `value` не ноль. Обычно наш OracleRelay (адаптер под Chainlink) для этого коллатерала. |

Если один из контрактов не соответствует требованиям, транзакция `addMarket` в реестре откатится с `Registry__InvalidParams()`.
