# Troubleshooting

## MCP Tool Call Prefix

**Problem:** Gemini agent calls MCP tools without the prefix (e.g. `getCase` instead of `testrail__getCase`).

**Solution:** Explicitly add the rule in `prompts/master.md`:
```
All TestRail MCP tools MUST be called with the `testrail__` prefix
All Playwright MCP tools MUST be called with the `playwright__` prefix
```

**Symptom in logs:** `Tool not found: getCase` or the agent cannot complete requests to TestRail.

---

## Gemini API Quota Exceeded

**Problem:** `429 Resource Exhausted` — Gemini API quota exceeded.

**Solution:**
1. Switch to `gemini-2.5-flash` (cheaper) instead of `gemini-2.5-pro`
2. Check quotas in Google AI Studio
3. Enable billing on the Google Cloud project for higher limits

**Symptom:** Agent stops mid-execution with a 429 error.

---

## Docker shm_size

**Problem:** Playwright crashes with a `shared memory` error when running Chromium.

**Solution:** Set `--shm-size=2gb` in `docker run` (or `shm_size: '2gb'` in docker-compose).

**Symptom:** `Error: Failed to launch the browser process` or `SIGBUS` in Chromium logs.

---

## GitHub Token Permissions

**Problem:** `gh pr create` fails with `GraphQL error: Resource not accessible`.

**Solution:** GitHub PAT must have scopes: `repo` + `workflow`.

**Symptom:** `gh auth status` shows missing scopes.

---

## TestRail MCP — Invalid URL Format

**Problem:** `@bun913/mcp-testrail` requires URL without trailing slash.

**Solution:** `TESTRAIL_URL=https://blackrockng.testrail.io` (no trailing `/`).

**Symptom:** 404 errors when making requests to the TestRail API.

---

## Gemini --loop Flag

**Problem:** Without `--loop`, the agent may stop after a single tool round-trip.

**Solution:** Use `gemini --loop` or `gemini --yolo` for autonomous operation.

**Symptom:** Agent makes one MCP call and exits without finishing the test.

---

## npm ci failed — No package-lock.json

**Problem:** `npm ci` fails if the target repository has no `package-lock.json`.

**Solution:** Add `package-lock.json` to the root of the target repo, or replace `npm ci` with `npm install` in the entrypoint.

**Symptom:** `npm error The \`npm ci\` command can only install with an existing package-lock.json`.

---

## Docker Build Cache on Jenkins

**Problem:** Jenkins agent has no Docker layer cache between builds — every build starts from scratch.

**Solution:** Use `--cache-from` or configure a Docker registry to store intermediate images.

**Alternative:** Run Docker with a bind mount for the node_modules cache.
