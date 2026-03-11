# Architecture

## Overview

Gemini QA Agent — a Docker container that automatically generates Playwright tests
based on a task from TestRail and opens a Pull Request in GitHub.

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

1. Jenkins passes `TESTRAIL_CASE_ID` as a parameter
2. `entrypoint.sh` clones the target GitHub repository
3. `envsubst` substitutes variables in `.gemini.settings.json` and the prompt
4. `gemini` CLI launches the agent with two MCP servers (testrail, playwright)
5. Agent reads the TestRail case → inspects app with browser → writes test → creates PR

## Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | MS Playwright base image + Gemini CLI + gh CLI installation |
| `entrypoint.sh` | Orchestrator: git clone, envsubst, run gemini |
| `.gemini.settings.json.template` | MCP servers (testrail, playwright) |
| `prompts/master.md` | Agent system prompt (workflow, rules) |
| `prompts/task-template.md` | Task template with TESTRAIL_* variables |
| `Jenkinsfile` | CI pipeline: Validate → Build → Run |
| `docker-compose.yml` | Local development run |

## Environment Variables

### Via Jenkins Credentials
- `GEMINI_API_KEY` — Google Gemini API key
- `GITHUB_TOKEN` / `GH_TOKEN` — GitHub PAT (scopes: repo, workflow)
- `TESTRAIL_API_KEY` — TestRail API key

### Via Jenkins Global Properties
- `TESTRAIL_URL` — https://blackrockng.testrail.io/
- `TESTRAIL_USERNAME` — qa@protonixltd.com
- `TESTRAIL_PROJECT_ID` — 3

### Via Jenkins Build Parameters
- `TESTRAIL_CASE_ID` — e.g. C738972
- `GITHUB_REPO` — e.g. dkuznetsov21/playwright-example
- `GEMINI_MODEL` — gemini-2.5-flash | gemini-2.5-pro
