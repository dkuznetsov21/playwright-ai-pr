## Task

- TestRail Project ID: ${TESTRAIL_PROJECT_ID}
- TestRail Case ID: ${TESTRAIL_CASE_ID}
- Target branch: feature/auto-${TESTRAIL_CASE_ID}

Fetch the test case from TestRail. The application URL is in the test case preconditions.
Use Playwright browser MCP tools to inspect the live app, get real locators,
implement the test, verify it passes, and open a PR.
