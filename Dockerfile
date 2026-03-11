FROM mcr.microsoft.com/playwright:v1.58.2-noble

LABEL org.opencontainers.image.title="gemini-qa-agent" \
      org.opencontainers.image.description="Gemini CLI agent that generates Playwright tests from TestRail cases" \
      org.opencontainers.image.source="https://github.com/dkuznetsov21/gemini-qa-agent"

RUN apt-get update && apt-get install -y --no-install-recommends \
    gh \
    gettext-base \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Gemini CLI + TestRail MCP server
RUN npm install -g @google/gemini-cli @bun913/mcp-testrail

# Template config for Gemini CLI with TestRail MCP (variables substituted in entrypoint)
COPY .gemini.settings.json.template /root/.gemini.settings.json.template

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Prompt files baked into the image
COPY prompts/ /prompts/

WORKDIR /workspace
ENTRYPOINT ["/entrypoint.sh"]
