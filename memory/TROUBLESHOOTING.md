# Troubleshooting

## MCP Tool Call Prefix

**Проблема:** Gemini агент вызывает MCP инструменты без префикса (например, `getCase` вместо `testrail__getCase`).

**Решение:** В `prompts/master.md` явно указать правило:
```
All TestRail MCP tools MUST be called with the `testrail__` prefix
All Playwright MCP tools MUST be called with the `playwright__` prefix
```

**Симптом в логах:** `Tool not found: getCase` или агент не может выполнить запрос к TestRail.

---

## Gemini API Quota Exceeded

**Проблема:** `429 Resource Exhausted` — превышена квота Gemini API.

**Решение:**
1. Переключиться на `gemini-2.5-flash` (дешевле) вместо `gemini-2.5-pro`
2. Проверить квоты в Google AI Studio
3. Включить биллинг на Google Cloud проекте для более высоких лимитов

**Симптом:** агент останавливается на середине выполнения с ошибкой 429.

---

## Docker shm_size

**Проблема:** Playwright падает с ошибкой `shared memory` при работе с Chromium.

**Решение:** Установить `--shm-size=2gb` в `docker run` (или `shm_size: '2gb'` в docker-compose).

**Симптом:** `Error: Failed to launch the browser process` или `SIGBUS` в логах Chromium.

---

## GitHub Token Permissions

**Проблема:** `gh pr create` завершается с `GraphQL error: Resource not accessible`.

**Решение:** GitHub PAT должен иметь scopes: `repo` + `workflow`.

**Симптом:** `gh auth status` показывает отсутствующие scopes.

---

## TestRail MCP — неверный URL формат

**Проблема:** `@bun913/mcp-testrail` требует URL без trailing slash.

**Решение:** `TESTRAIL_URL=https://blackrockng.testrail.io` (без `/` в конце).

**Симптом:** ошибки 404 при запросах к TestRail API.

---

## Gemini --loop флаг

**Проблема:** Без `--loop` агент может остановиться после одного round-trip инструментов.

**Решение:** Использовать `gemini --loop` или `gemini --yolo` для автономной работы.

**Симптом:** агент делает один вызов MCP и завершается, не дописав тест.

---

## npm ci failed — нет package-lock.json

**Проблема:** `npm ci` падает если в target репозитории нет `package-lock.json`.

**Решение:** Добавить `package-lock.json` в корень target репо, или заменить `npm ci` на `npm install` в entrypoint.

**Симптом:** `npm error The `npm ci` command can only install with an existing package-lock.json`.

---

## Docker Build кэш на Jenkins

**Проблема:** Jenkins агент не имеет кэша Docker слоёв между сборками — каждая сборка с нуля.

**Решение:** Использовать `--cache-from` или настроить Docker registry для хранения промежуточных образов.

**Альтернатива:** Запускать Docker с bind mount для node_modules кэша.
