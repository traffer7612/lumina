# Slither — статический анализ контрактов Ceitnot

[Slither](https://github.com/crytic/slither) — статический анализатор Solidity от Trail of Bits. Используется для автоматической проверки контрактов Ceitnot; отчёты выкладываются в открытый доступ.

## Установка

```bash
pip install slither-analyzer
# или
pip3 install slither-analyzer
```

Требуется Python 3.8+ и установленный компилятор Solidity (например через Foundry: `forge build` должен проходить в корне репозитория).

## Запуск из корня репозитория

```bash
# Из корня проекта (где лежат src/, lib/)
cd F:\aura   # или путь к вашему клону

# JSON-отчёт (для CI и парсинга)
slither . --json docs/reports/slither-report.json

# Человекочитаемый отчёт в консоль
slither .

# Markdown-отчёт в папку
slither . --markdown-root docs/reports
```

Перед первым запуском выполните `forge build`, чтобы артефакты компиляции были на месте.

## Где хранить отчёты

- **docs/reports/** — создайте папку и положите сюда `slither-report.json` и/или markdown. Добавьте `docs/reports/*.json` в `.gitignore` при необходимости или коммитьте отчёты для прозрачности.
- В CI (GitHub Actions и т.д.) можно генерировать отчёт на каждый коммит и публиковать артефакт или загружать на docs.ceitnot.finance.

## Интерпретация

- **High/Medium** по нашему коду — исправлены (см. [SECURITY-AUDIT.md](SECURITY-AUDIT.md)).
- **Low/Informational** — многие приняты как допустимые паттерны (WAD/RAY, timestamp, CEI уже соблюдён в критичных местах).
- Предупреждения по **lib/** (OpenZeppelin, forge-std) — известные паттерны сторонних библиотек, не требуют правок в нашем репозитории.

Итоги и категоризацию см. в [SECURITY-AUDIT.md](SECURITY-AUDIT.md), раздел «Статический анализ — Slither».
