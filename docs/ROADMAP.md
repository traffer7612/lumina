# Roadmap Ceitnot Protocol

Живой план развития и выхода в стабильный **production**. Детальный релиз-гейт — в [`TOKENOMICS-PROD-CHECKLIST.md`](TOKENOMICS-PROD-CHECKLIST.md); адреса Arbitrum — в [`PRODUCTION-ADDRESSES-ARBITRUM.md`](PRODUCTION-ADDRESSES-ARBITRUM.md).

Статусы ниже — ориентиры по приоритету, не жёсткие даты.

---

## Фаза A — Закрыть прод-гейт (core)

**Цель:** протокол и UI безопасно используются публично, документы и ончейн-состояние согласованы.

| Задача | Критерий готовности |
|--------|---------------------|
| Миграция PSM | Timelock исполнил `CeitnotUSD.addMinter(newPSM)`; на Arbiscan `minters(newPSM) == true`; ликвидность в новом PSM; затем governance `removeMinter(oldPSM)` после переноса резервов. |
| Публичный smoke | На прод-деплое: connect wallet, список рынков, governance, swap quote **и** успешный swap (tx в Evidence Log). |
| Tokenomics disclosure | Circulating / FDV, политика supply, vesting + unlock-календарь (или явная ссылка на cap table). |
| Fee & treasury | Конкретные назначения потоков комиссий, каденс `distributeRevenue`, адрес(а) treasury / лимиты трат. |
| Рынки и оракулы | Публичная таблица параметров по каждому live market + feeds и политика stale price (числа, не только шаблон). |
| Операционка | Заполнены роли в [`INCIDENT-ROLLBACK-RUNBOOK.md`](INCIDENT-ROLLBACK-RUNBOOK.md); включены алерты на minter/admin/pause/крупные outflows. |

---

## Фаза B — Устойчивость и доверие

**Цель:** предсказуемое управление рисками и прозрачность для держателей и интеграторов.

| Направление | Что делаем |
|-------------|------------|
| Аудит / пост-аудит | Актуализировать [`SECURITY-AUDIT.md`](SECURITY-AUDIT.md) под последние изменения контрактов; при необходимости повторный scope. |
| Bug bounty | Сверить [`BUG-BOUNTY.md`](BUG-BOUNTY.md) с реальными контрактами в проде и лимитами выплат. |
| Governance | Anti-capture policy с целевым участием; регулярный пересмотр quorum/threshold относительно ve supply. |
| Риск-редакция | Шаблон risk memo на каждый новый collateral; публикация rationale к текущим LTV / liquidation caps. |

---

## Фаза C — Рост продукта

**Цель:** больше полезного протоколу ликвидности и удобства без потери безопасности.

Возможные направления (приоритет задаёт DAO):

- Новые collateral markets после onboarding checklist и oracle review.
- Улучшение UX: онбординг, прозрачность комиссий в UI, статус миграций контрактов.
- Инструменты для аналитиков: экспорт ключевых метрик, подписки на события.
- Composability: документированные интеграции (router, vault patterns), партнёрские сценарии.

---

## Фаза D — Долгий горизонт

- Масштабирование на дополнительные сети (если совпадает с экономикой безопасности и поддержки).
- Исследование механизмов стабилизации и резервов сверх минимально необходимого PSM.
- Эволюция токеномики под управлением governance при сохранении предсказуемости для пользователей.

---

## Как читать вместе с чеклистом

- Пункты **Фазы A** почти один в один закрывают оставшиеся `🟡` в [`TOKENOMICS-PROD-CHECKLIST.md`](TOKENOMICS-PROD-CHECKLIST.md).
- После завершения Фазы A имеет смысл **зафиксировать дату** «public production» и обновить Evidence Log (proposal id, tx hashes).

При изменении приоритетов обновляйте этот файл одним PR и краткой заметкой в релизных нотах или в Discord/Twitter.
