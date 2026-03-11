# Architecture Decisions

## Docker Runs on Jenkins (not native execution)

**Decision:** Jenkins runs `docker build` + `docker run` rather than installing dependencies natively.

**Reasons:**
- Playwright requires specific browser versions — MS Playwright Docker image (`mcr.microsoft.com/playwright`) handles this out of the box
- Isolation — each Jenkins job gets a clean container with no artifacts from previous runs
- Reproducibility — identical behavior locally (`docker-compose`) and on CI (`docker run`)
- No need to install Node.js, Playwright, browsers, or gh CLI on the Jenkins agent

**Trade-off:** First build is slow (~5-10 min), but layer cache speeds up subsequent builds.

---

## docker-compose for Local Development Only

**Decision:** CI uses `docker build` + `docker run` directly, without docker-compose.

**Reasons:**
- docker-compose may not be available on the Jenkins agent
- `docker run --rm` is simpler for CI: no need for `docker-compose down`
- Explicit `-e` flags are visible in Jenkins logs (no .env file required)

---

## Gemini CLI with --yolo Flag

**Decision:** `gemini --yolo` disables interactive confirmations.

**Reasons:**
- There is no interactive terminal inside the Docker container for confirmations
- The agent must operate autonomously without operator intervention

**Risk:** The agent may perform unintended operations. Mitigation — scope is limited via the prompt.

---

## Jira Removed from Pipeline

**Decision:** Only `TESTRAIL_CASE_ID` as input parameter, without Jira.

**Reasons:**
- Simplifies the pipeline — one parameter instead of two
- Removes dependency on Jira API and its availability
- TestRail is the single source of truth for test cases

---

## Prompts as Files in the Repository

**Decision:** `prompts/master.md` and `prompts/task-template.md` are copied into the Docker image.

**Reasons:**
- Prompts are versioned alongside the code
- Easy to modify without rebuilding the image (if mounted as a volume locally)
- `envsubst` handles environment variable substitution in templates

---

## MCP Servers: testrail + playwright

**Decision:** Two MCP servers instead of direct API calls.

**Reasons:**
- Gemini CLI natively supports the MCP protocol
- Playwright MCP gives the agent a real browser to inspect the UI
- TestRail MCP hides HTTP authentication details from the agent
- Agent uses high-level tools (browser_snapshot, getCase) instead of raw HTTP requests
