#!/usr/bin/env bash
set -e
cd /home/anand/projects/maskr

TOKEN=$(node -e "const fs = require('fs'); const cfg = JSON.parse(fs.readFileSync('/mnt/c/Users/anand.selvakumar/.gemini/config/mcp_config.json', 'utf8')); console.log(cfg.mcpServers['github-mcp-server'].env.GITHUB_PERSONAL_ACCESS_TOKEN);")

git commit --amend -m "fix(release): prominent version display across header, admin login gate, footer, and api"
git tag -fa v1.8.1 -m "v1.8.1: permanent custom rule persistence and prominent version display across entire application"
git push "https://anandprabhusk:${TOKEN}@github.com/anandprabhusk/filtr.git" main --force
git push "https://anandprabhusk:${TOKEN}@github.com/anandprabhusk/filtr.git" v1.8.1 --force

echo "AMEND_SUCCESS"
