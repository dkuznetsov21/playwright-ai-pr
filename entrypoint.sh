#!/bin/bash
set -eo pipefail

echo "=========================================="
echo " Gemini QA Agent"
echo " Model:   ${GEMINI_MODEL:-gemini-2.5-flash-lite}"
echo " Repo:    ${GITHUB_REPO}"
echo " Case ID: ${TESTRAIL_CASE_ID}"
echo "=========================================="

# Validate required environment variables
: "${GEMINI_API_KEY:?GEMINI_API_KEY is required}"
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${GITHUB_REPO:?GITHUB_REPO is required}"
: "${TESTRAIL_CASE_ID:?TESTRAIL_CASE_ID is required}"
: "${TESTRAIL_URL:?TESTRAIL_URL is required}"
: "${TESTRAIL_USERNAME:?TESTRAIL_USERNAME is required}"
: "${TESTRAIL_API_KEY:?TESTRAIL_API_KEY is required}"
: "${TESTRAIL_PROJECT_ID:?TESTRAIL_PROJECT_ID is required}"

# Strip optional 'C' prefix — TestRail MCP API expects numeric ID
TESTRAIL_CASE_ID="${TESTRAIL_CASE_ID#C}"

# Strip trailing slash — @bun913/mcp-testrail requires URL without trailing slash
TESTRAIL_URL="${TESTRAIL_URL%/}"

# 1. Generate ~/.gemini/settings.json from template
echo ""
echo "[1/6] Generating Gemini MCP config..."
mkdir -p ~/.gemini
envsubst < /root/.gemini.settings.json.template > ~/.gemini/settings.json
echo "      -> ~/.gemini/settings.json created"

# 2. Git identity
echo ""
echo "[2/6] Setting git identity: ${GIT_USER_NAME:-Gemini Agent} <${GIT_USER_EMAIL:-gemini@ci.local}>"
git config --global user.name "${GIT_USER_NAME:-Gemini Agent}"
git config --global user.email "${GIT_USER_EMAIL:-gemini@ci.local}"

# 3. GitHub CLI auth
echo ""
echo "[3/6] Configuring GitHub CLI auth..."
export GH_TOKEN="${GITHUB_TOKEN}"

# 4. Clone repository
echo ""
echo "[4/6] Cloning ${GITHUB_REPO}..."
rm -rf /workspace/repo
git clone "https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" /workspace/repo
echo "      -> Cloned into /workspace/repo"
cd /workspace/repo

# 5. Install project dependencies
echo ""
echo "[5/6] Installing npm dependencies..."
npm ci
echo "      -> Done"

# 6. Build final prompt
echo ""
echo "[6/6] Building prompt (case: ${TESTRAIL_CASE_ID})..."
PROMPT_FILE="${PROMPT_FILE:-/prompts/task-template.md}"
MASTER_PROMPT="$(cat /prompts/master.md)

---

$(envsubst < "$PROMPT_FILE")"
echo "      -> Prompt ready"

echo ""
echo "=========================================="
echo " Launching Gemini agent..."
echo "=========================================="
echo ""

# 7. Run Gemini CLI — stream-json piped through formatter for real-time visibility
# set -o pipefail ensures non-zero exit from gemini propagates through the pipe
GEMINI_API_KEY="${GEMINI_API_KEY}" gemini \
  --yolo \
  --model "${GEMINI_MODEL:-gemini-2.5-flash-lite}" \
  --output-format stream-json \
  -p "$MASTER_PROMPT" \
  | jq -r --unbuffered '
    if .type == "init" then
      "[INIT] session=\(.session_id) model=\(.model)"
    elif .type == "message" and .role == "assistant" then
      "\(.content)"
    elif .type == "tool_use" then
      "\n[TOOL→] \(.tool_name) \(.parameters | tostring | .[0:200])"
    elif .type == "tool_result" then
      "[←TOOL] \(.tool_id | split("_")[0]) status=\(.status)"
    elif .type == "error" then
      "[ERROR] \(.message // tostring)"
    else empty
    end
  ' 2>/dev/null
