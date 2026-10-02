#!/usr/bin/env bash
# secret-scan.sh <base> [head]  — scan the commits base..head for secrets before a push.
# Exit 0 clean; 1 leaks found (redacted report on stdout); 2 scanner missing or bad range.
set -euo pipefail
base=${1:?usage: secret-scan.sh <base> [head]}; head=${2:-HEAD}
command -v gitleaks >/dev/null || { echo "BLOCKED: gitleaks not installed (run install.sh --check)"; exit 2; }
git rev-parse --verify -q "$base^{commit}" >/dev/null && git rev-parse --verify -q "$head^{commit}" >/dev/null \
  || { echo "BLOCKED: bad range $base..$head"; exit 2; }
gitleaks git --no-banner --redact --log-opts="$base..$head" .
