# Architecture

## Overview

Gemini QA Agent — Docker-контейнер, который автоматически генерирует Playwright-тесты
по заданию из TestRail и открывает Pull Request в GitHub.

## Components

```
┌─────────────────────────────────────────────────────────┐
│                    Jenkins / Local                       │
│                                                          │
│  docker build → docker run                               │
│       │                                                  │
│       ▼                                                  │
│  ┌─────────────────────────────────────────────────┐    │
│  │              Docker Container                   │    │
│  │                                                  │    │
│  │  entrypoint.sh                                   │    │
│  │    1. git clone GITHUB_REPO                      │    │
│  │    2. envsubst → .gemini.settings.json           │    │
│  │    3. envsubst → task prompt                     │    │
│  │    4. gemini --model ... --yolo -p <prompt>      │    │
│  │         │                                        │    │
│  │         ├── MCP: testrail__getCase               │    │
│  │         ├── MCP: playwright__browser_navigate    │    │
│  │         ├── MCP: playwright__browser_snapshot    │    │
│  │         ├── shell: npx playwright test           │    │
│  │         └── shell: gh pr create                  │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Data Flow

1. Jenkins передаёт `TESTRAIL_CASE_ID` как параметр
2. `entrypoint.sh` клонирует target GitHub репо
3. `envsubst` подставляет переменные в `.gemini.settings.json` и промпт
4. `gemini` CLI запускает агента с двумя MCP серверами (testrail, playwright)
5. Агент читает TestRail case → исследует app браузером → пишет тест → создаёт PR

## Key Files

| Файл | Назначение |
|------|-----------|
| `Dockerfile` | Базовый образ MS Playwright + установка gemini CLI + gh CLI |
| `entrypoint.sh` | Оркестратор: git clone, envsubst, запуск gemini |
| `.gemini.settings.json.template` | MCP серверы (testrail, playwright) |
| `prompts/master.md` | Системный промпт агента (workflow, правила) |
| `prompts/task-template.md` | Шаблон задачи с переменными TESTRAIL_* |
| `Jenkinsfile` | CI пайплайн: Validate → Build → Run |
| `docker-compose.yml` | Локальный запуск для разработки |

## Environment Variables

### Через Jenkins Credentials
- `GEMINI_API_KEY` — Google Gemini API key
- `GITHUB_TOKEN` / `GH_TOKEN` — GitHub PAT (scopes: repo, workflow)
- `TESTRAIL_API_KEY` — TestRail API key

### Через Jenkins Global Properties
- `TESTRAIL_URL` — https://blackrockng.testrail.io/
- `TESTRAIL_USERNAME` — qa@protonixltd.com
- `TESTRAIL_PROJECT_ID` — 3

### Через Jenkins Build Parameters
- `TESTRAIL_CASE_ID` — e.g. C738972
- `GITHUB_REPO` — e.g. dkuznetsov21/playwright-example
- `GEMINI_MODEL` — gemini-2.5-flash | gemini-2.5-pro
