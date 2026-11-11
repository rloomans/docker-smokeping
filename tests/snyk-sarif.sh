#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

jq -f .github/scripts/normalize-snyk-sarif.jq <<'JSON' | jq -e '
  .runs[0].tool.driver.rules == [
    {"properties": {"other": 1}},
    {"properties": {}},
    {"properties": {"security-severity": "7.5"}}
  ] and
  .runs[0].results == [
    {"ruleId": "invalid"},
    {"ruleId": "mixed", "fixes": [
      {"artifactChanges": [{"replacements": [{"insertedContent": {"text": "valid"}}]}]},
      {"artifactChanges": [{"replacements": [{"insertedContent": {"binary": "dGVzdA=="}}]}]}
    ]},
    {"ruleId": "no-fixes"}
  ] and
  .runs[1].results == [{"ruleId": "second-run"}]
' > /dev/null
{
  "runs": [
    {
      "tool": {"driver": {"rules": [
        {"properties": {"security-severity": null, "other": 1}},
        {"properties": {"security-severity": "null"}},
        {"properties": {"security-severity": "7.5"}}
      ]}},
      "results": [
        {"ruleId": "invalid", "fixes": [
          {"artifactChanges": [{"replacements": [{"insertedContent": {"text": false}}]}]}
        ]},
        {"ruleId": "mixed", "fixes": [
          {"artifactChanges": [{"replacements": [{"insertedContent": {"text": "valid"}}]}]},
          {"artifactChanges": [{"replacements": [{"insertedContent": {"text": null}}]}]},
          {"artifactChanges": [{"replacements": [{"insertedContent": {"binary": "dGVzdA=="}}]}]}
        ]},
        {"ruleId": "no-fixes"}
      ]
    },
    {"results": [
      {"ruleId": "second-run", "fixes": [
        {"artifactChanges": [{"replacements": [{"insertedContent": {"text": 42}}]}]}
      ]}
    ]}
  ]
}
JSON
