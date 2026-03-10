# Документация Lumina (docs.lumina.finance)

Эту папку можно использовать как источник для **GitBook** (docs.lumina.finance): подключите репозиторий к GitBook и укажите папку `docs/` или скопируйте файлы.

## Содержание

| Документ | Описание |
|----------|----------|
| [INTEREST-RATES.md](INTEREST-RATES.md) | Математика процентных ставок (kink-модель, утилизация, RAY/WAD). |
| [LIQUIDATION.md](LIQUIDATION.md) | Механика ликвидации: Health Factor, кто ликвидирует, bad debt. |
| [SMART-CONTRACTS.md](SMART-CONTRACTS.md) | Смарт-контракты и адреса (Sepolia и др. сети). |
| [SECURITY-AUDIT.md](SECURITY-AUDIT.md) | Аудит: тесты, Slither, отчёты, Bug Bounty. |
| [BUG-BOUNTY.md](BUG-BOUNTY.md) | Программа вознаграждений за уязвимости. |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Архитектура проекта. |
| [DEPLOY.md](DEPLOY.md) | Деплой контрактов. |
| [VERCEL.md](VERCEL.md) | Деплой фронта на Vercel. |

## Настройка GitBook

1. Создайте пространство на [gitbook.com](https://www.gitbook.com) и привяжите репозиторий (GitHub/GitLab).
2. Root path укажите как `docs` или выберите только нужные файлы.
3. Домен docs.lumina.finance настройте в настройках GitBook (Custom domain).

Альтернатива: экспорт Markdown в статический сайт (MkDocs, Docusaurus) и хостинг на том же домене.
