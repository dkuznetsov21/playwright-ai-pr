# Gemini QA Agent

A Docker container with Gemini CLI that automatically generates Playwright tests
based on a test case from TestRail and opens a Pull Request in GitHub.

Can be run locally via `docker-compose` or on Jenkins via `docker run`.

---

## How It Works

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

**Agent Workflow:**

1. Reads `CLAUDE.md` in the target repository — project conventions
2. Fetches the test case via `testrail__getCase`
3. Opens the browser (Playwright MCP, Chromium headless) — inspects the live application
4. Takes an accessibility tree snapshot (`browser_snapshot`) — retrieves real locators
5. Writes the test following the Page Object pattern
6. Runs `npx playwright test` — fixes if it fails
7. `git push` + `gh pr create`

---

## Project Structure

```
.
├── Dockerfile                        # Playwright base image + Gemini CLI + gh CLI
├── Jenkinsfile                       # CI pipeline: Validate → Build → Run
├── docker-compose.yml                # Local development run
├── entrypoint.sh                     # Orchestrator inside the container
├── .gemini.settings.json.template    # MCP servers (testrail, playwright)
├── .env.example                      # Example environment variables
├── prompts/
│   ├── master.md                     # Agent system prompt (workflow, rules)
│   └── task-template.md              # Task template (variables via envsubst)
└── memory/
    ├── ARCHITECTURE.md               # Architecture and data flows
    ├── DECISIONS.md                  # Architectural decision rationale
    └── TROUBLESHOOTING.md            # Known issues and solutions
```

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) ≥ 24
- Docker Compose ≥ 2.x (for local run)
- Accounts: Google AI Studio, GitHub, TestRail

---

## Quick Start (locally)

```bash
# 1. Clone the repo
git clone https://github.com/dkuznetsov21/gemini-qa-agent.git
cd gemini-qa-agent

# 2. Configure environment variables
cp .env.example .env
# Open .env and fill in real values

# 3. Run the agent
docker-compose build
TESTRAIL_CASE_ID=C738972 docker-compose --env-file .env up
```

---

## Configuring .env

Copy `.env.example` → `.env` and fill in:

```env
# Gemini
GEMINI_API_KEY=AIzaSy-...
GEMINI_MODEL=gemini-2.5-flash-lite   # or gemini-2.5-flash

# GitHub
GITHUB_TOKEN=ghp_...
GITHUB_REPO=myorg/myrepo

# TestRail
TESTRAIL_URL=https://mycompany.testrail.io
TESTRAIL_USERNAME=user@company.com
TESTRAIL_API_KEY=...
TESTRAIL_PROJECT_ID=5

# Task
TESTRAIL_CASE_ID=C123
```

Getting API keys:
- **Gemini API Key** — [aistudio.google.com](https://aistudio.google.com) → Get API Key
- **GitHub PAT** — Settings → Developer settings → Personal access tokens → scopes: `repo`, `workflow`
- **TestRail API Key** — My Settings → API Keys → Add Key

---

## Jenkins Setup

### Step 1 — Credentials

**Manage Jenkins → Credentials → System → Global domains → Add Credentials**

| Credential ID | Type | Value |
|---|---|---|
| `gemini-api-key` | Secret text | Gemini API key |
| `github-token` | Secret text | GitHub PAT (scopes: `repo`, `workflow`) |
| `testrail-api-key` | Secret text | TestRail API key |

### Step 2 — Global Environment Variables

**Manage Jenkins → System → Global Properties → Environment variables**

| Variable | Example value |
|---|---|
| `TESTRAIL_URL` | `https://mycompany.testrail.io` |
| `TESTRAIL_USERNAME` | `qa@company.com` |
| `TESTRAIL_PROJECT_ID` | `3` |

### Step 3 — Pipeline Job

1. **New Item** → name `gemini-qa-agent` → **Pipeline** → OK
2. Pipeline Definition: **Pipeline script from SCM**
   - SCM: Git, Repository URL: this repository
   - Script Path: `Jenkinsfile`
3. Save

### Step 4 — Run

**Build with Parameters:**

| Parameter | Description | Example |
|---|---|---|
| `TESTRAIL_CASE_ID` | TestRail test case ID | `C738972` |
| `GITHUB_REPO` | Target repository | `myorg/myrepo` |
| `GEMINI_MODEL` | Gemini model | `gemini-2.5-flash-lite` |

### Expected Logs

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

## Customization

### Change Agent Instructions

Edit `prompts/master.md` — add project-specific details, restrictions, patterns.
After changes, rebuild the image:

```bash
docker-compose build
```

### Use a Different Task Template

Create `prompts/my-task.md` and set in `.env`:

```env
PROMPT_FILE=/prompts/my-task.md
```

---

## Troubleshooting

| Problem | Cause | Solution |
|---|---|---|
| `TESTRAIL_CASE_ID is required` | Parameter not passed | Pass `TESTRAIL_CASE_ID` in Build with Parameters |
| `gh: bad credentials` | Invalid `GITHUB_TOKEN` | Check scopes: `repo` + `workflow` |
| `GEMINI_API_KEY not set` | Key not passed | Check Jenkins Credential `gemini-api-key` |
| `npm ci` failed | No `package-lock.json` in target repo | Add `package-lock.json` to target repository |
| Playwright tests fail | Wrong locators | Agent reruns browser_snapshot and fixes |
| `429 Resource Exhausted` | Gemini quota exceeded | Switch to `gemini-2.5-flash-lite` or enable billing |
| `shm` Chromium errors | Insufficient shared memory | Already set to `--shm-size=2gb` |
| MCP tool not found | Wrong prefix | Prompt requires `testrail__` and `playwright__` prefix |

Full list of known issues: [memory/TROUBLESHOOTING.md](memory/TROUBLESHOOTING.md)

---

## Saving Logs

```bash
# Locally
docker-compose --env-file .env up 2>&1 | tee agent.log
```
