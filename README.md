# Gemini QA Agent

Docker-контейнер с Gemini CLI, который автоматически генерирует Playwright-тесты
по тест-кейсу из TestRail и открывает Pull Request в GitHub.

Запускается локально через `docker-compose` или на Jenkins через `docker run`.

---

## Как это работает

```
Jenkins / Local
      │
      ▼
docker build → docker run
      │
      ▼
┌─────────────────────────────────────────────────────────────┐
│  Docker Container (mcr.microsoft.com/playwright)            │
│                                                             │
│  entrypoint.sh                                              │
│    1. git clone GITHUB_REPO                                 │
│    2. envsubst → ~/.gemini/settings.json                    │
│    3. npm ci (target repo)                                  │
│    4. gemini --yolo -p <prompt>                             │
│         │                                                   │
│         ├─ MCP testrail──► getCase(TESTRAIL_CASE_ID)        │
│         ├─ MCP playwright─► browser_navigate / snapshot     │
│         ├─ shell ─────────► npx playwright test             │
│         └─ shell ─────────► git push → gh pr create         │
└─────────────────────────────────────────────────────────────┘
```

**Workflow агента:**

1. Читает `CLAUDE.md` в target репозитории — соглашения проекта
2. Получает тест-кейс через `testrail__getCase`
3. Открывает браузер (Playwright MCP, Chromium headless) — исследует live-приложение
4. Снимает accessibility tree (`browser_snapshot`) — получает реальные локаторы
5. Пишет тест по Page Object паттерну
6. Прогоняет `npx playwright test` — фиксит если падает
7. `git push` + `gh pr create`

---

## Структура проекта

```
.
├── Dockerfile                        # Playwright base image + Gemini CLI + gh CLI
├── Jenkinsfile                       # CI pipeline: Validate → Build → Run
├── docker-compose.yml                # Локальный запуск
├── entrypoint.sh                     # Оркестратор внутри контейнера
├── .gemini.settings.json.template    # MCP серверы (testrail, playwright)
├── .env.example                      # Пример переменных окружения
├── prompts/
│   ├── master.md                     # Системный промпт агента (workflow, правила)
│   └── task-template.md              # Шаблон задачи (переменные через envsubst)
└── memory/
    ├── ARCHITECTURE.md               # Архитектура и потоки данных
    ├── DECISIONS.md                  # Обоснование архитектурных решений
    └── TROUBLESHOOTING.md            # Известные проблемы и решения
```

---

## Предварительные требования

- [Docker](https://docs.docker.com/get-docker/) ≥ 24
- Docker Compose ≥ 2.x (для локального запуска)
- Аккаунты: Google AI Studio, GitHub, TestRail

---

## Быстрый старт (локально)

```bash
# 1. Клонируй репо
git clone https://github.com/dkuznetsov21/gemini-qa-agent.git
cd gemini-qa-agent

# 2. Настрой переменные окружения
cp .env.example .env
# Открой .env и заполни реальные значения

# 3. Запусти агента
docker-compose build
TESTRAIL_CASE_ID=C738972 docker-compose --env-file .env up
```

---

## Настройка .env

Скопируй `.env.example` → `.env` и заполни:

```env
# Gemini
GEMINI_API_KEY=AIzaSy-...
GEMINI_MODEL=gemini-2.5-flash-lite   # или gemini-2.5-flash

# GitHub
GITHUB_TOKEN=ghp_...
GITHUB_REPO=myorg/myrepo

# TestRail
TESTRAIL_URL=https://mycompany.testrail.io
TESTRAIL_USERNAME=user@company.com
TESTRAIL_API_KEY=...
TESTRAIL_PROJECT_ID=5

# Задача
TESTRAIL_CASE_ID=C123
```

Получение ключей:
- **Gemini API Key** — [aistudio.google.com](https://aistudio.google.com) → Get API Key
- **GitHub PAT** — Settings → Developer settings → Personal access tokens → scopes: `repo`, `workflow`
- **TestRail API Key** — My Settings → API Keys → Add Key

---

## Jenkins Setup

### Шаг 1 — Credentials

**Manage Jenkins → Credentials → System → Global domains → Add Credentials**

| Credential ID | Тип | Значение |
|---|---|---|
| `gemini-api-key` | Secret text | Gemini API key |
| `github-token` | Secret text | GitHub PAT (scopes: `repo`, `workflow`) |
| `testrail-api-key` | Secret text | TestRail API key |

### Шаг 2 — Global Environment Variables

**Manage Jenkins → System → Global Properties → Environment variables**

| Переменная | Пример значения |
|---|---|
| `TESTRAIL_URL` | `https://mycompany.testrail.io` |
| `TESTRAIL_USERNAME` | `qa@company.com` |
| `TESTRAIL_PROJECT_ID` | `3` |

### Шаг 3 — Pipeline Job

1. **New Item** → имя `gemini-qa-agent` → **Pipeline** → OK
2. Pipeline Definition: **Pipeline script from SCM**
   - SCM: Git, Repository URL: этот репозиторий
   - Script Path: `Jenkinsfile`
3. Сохранить

### Шаг 4 — Запуск

**Build with Parameters:**

| Параметр | Описание | Пример |
|---|---|---|
| `TESTRAIL_CASE_ID` | ID тест-кейса в TestRail | `C738972` |
| `GITHUB_REPO` | Target репозиторий | `myorg/myrepo` |
| `GEMINI_MODEL` | Модель Gemini | `gemini-2.5-flash-lite` |

### Ожидаемые логи

```
[Validate] TESTRAIL_CASE_ID = C738972 ✓
[Build Agent Image] Successfully built abc123...
[Run Agent] ==========================================
[Run Agent]  Gemini QA Agent
[Run Agent]  Model:   gemini-2.5-flash-lite
[Run Agent]  Repo:    myorg/myrepo
[Run Agent]  Case ID: C738972
[Run Agent] ==========================================
[Run Agent] [INIT] session=xyz model=gemini-2.5-flash-lite
[Run Agent] [TOOL→] testrail__getCase {"case_id":"C738972"}
[Run Agent] [TOOL→] playwright__browser_navigate {"url":"https://app.example.com"}
[Run Agent] [TOOL→] playwright__browser_snapshot {}
[Run Agent] Running: npx playwright test tests/auto-C738972.spec.ts
[Run Agent] All tests passed.
[Run Agent] [TOOL→] default_api__run_shell_command {"command":"gh pr create ..."}
[Run Agent] PR: https://github.com/myorg/myrepo/pull/42
Agent completed. PR created in myorg/myrepo
```

---

## Кастомизация

### Изменить инструкции агента

Отредактируй `prompts/master.md` — добавь специфику проекта, запреты, паттерны.
После изменений пересобери образ:

```bash
docker-compose build
```

### Использовать другой шаблон задачи

Создай `prompts/my-task.md` и укажи в `.env`:

```env
PROMPT_FILE=/prompts/my-task.md
```

---

## Диагностика

| Проблема | Причина | Решение |
|---|---|---|
| `TESTRAIL_CASE_ID is required` | Параметр не передан | Передай `TESTRAIL_CASE_ID` в Build with Parameters |
| `gh: bad credentials` | Невалидный `GITHUB_TOKEN` | Проверь scopes: `repo` + `workflow` |
| `GEMINI_API_KEY not set` | Ключ не передан | Проверь Jenkins Credential `gemini-api-key` |
| `npm ci` failed | Нет `package-lock.json` в target репо | Добавь `package-lock.json` в target репозиторий |
| Playwright тесты падают | Неверные локаторы | Агент перезапускает browser_snapshot и чинит |
| `429 Resource Exhausted` | Превышена квота Gemini | Переключись на `gemini-2.5-flash-lite` или включи биллинг |
| `shm` ошибки Chromium | Мало shared memory | Уже выставлено `--shm-size=2gb` |
| MCP tool not found | Неверный prefix | Промпт требует `testrail__` и `playwright__` prefix |

Полный список известных проблем: [memory/TROUBLESHOOTING.md](memory/TROUBLESHOOTING.md)

---

## Сохранение логов

```bash
# Локально
docker-compose --env-file .env up 2>&1 | tee agent.log
```
