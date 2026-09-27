#!/usr/bin/env bash
# install.sh [--check] [--watchdog] [--smoke]
# Installs the lanes harness for Claude Code on this machine (re-runnable; replaced files are backed up as .bak.<ts>):
#   ~/.local/bin: claude-via, claude-deepseek, claude-glm, model-relay, relay-guard, codex-review
#   ~/.claude/{deepseek,glm}.json  (routing only: base URL, model, NAME of the key variable — never the key)
#   ~/.claude/agents/{deepseek,glm,codex}.md (guarded relays) + {opus-lane,sonnet-lane}.md (tiered Claude lane coders)
# --check    only report what is installed / missing (no writes)
# --watchdog install a systemd user timer running lane-watchdog.sh clean at :17 and :47 (Linux)
# --smoke    run one tiny task through each provider in a temp dir (costs fractions of a cent)
set -euo pipefail
K="$(cd "$(dirname "$0")" && pwd)"; TS=$(date +%Y%m%d%H%M%S); CHECK=0; WATCHDOG=0; SMOKE=0
for a in "$@"; do case $a in --check) CHECK=1;; --watchdog) WATCHDOG=1;; --smoke) SMOKE=1;; *) echo "unknown option $a"; exit 2;; esac; done
keyval() { local v="${!1:-}"; [ -n "$v" ] || v="$(bash -ic "printf %s \"\$$1\"" 2>/dev/null || true)"; printf '%s' "$v"; }
put() { # put <src> <dest> <mode>  — atomic replace (never edit a running script in place)
  local src=$1 dest=$2 mode=$3 tmp; tmp="$(dirname "$dest")/.$(basename "$dest").tmp.$$"
  sed "s#@@HOME@@#$HOME#g" "$src" > "$tmp"
  if [ -f "$dest" ] && ! cmp -s "$tmp" "$dest"; then cp -p "$dest" "$dest.bak.$TS"; echo "  backed up $dest"; fi
  chmod "$mode" "$tmp"; mv -f "$tmp" "$dest"; echo "  installed $dest"
}
if [ $CHECK = 0 ]; then
  mkdir -p "$HOME/.local/bin" "$HOME/.local/state" "$HOME/.claude/agents"
  for f in claude-via claude-deepseek claude-glm model-relay relay-guard codex-review; do put "$K/bin/$f" "$HOME/.local/bin/$f" 755; done
  for p in deepseek glm; do put "$K/config/$p.json" "$HOME/.claude/$p.json" 600; done
  for a in deepseek glm codex opus-lane sonnet-lane; do put "$K/agents/$a.md" "$HOME/.claude/agents/$a.md" 644; done
  chmod +x "$K"/lane/*.sh
fi
echo "--- prerequisites"
for c in claude git python3 curl; do command -v $c >/dev/null && echo "  ok: $c" || echo "  MISSING: $c (required)"; done
command -v codex >/dev/null && echo "  ok: codex (Codex reviews on your ChatGPT plan)" || echo "  optional: codex CLI not found — reviews fall back to Claude reviewers (install: npm i -g @openai/codex, then 'codex login')"
command -v bd >/dev/null && echo "  ok: bd (Beads tracker)" || echo "  optional: bd (Beads) not found — the skill uses the project's own tracker or asks you"
command -v docker >/dev/null && echo "  ok: docker (disposable test databases)" || echo "  optional: docker not found — agents cannot spin up disposable databases"
case ":$PATH:" in *":$HOME/.local/bin:"*) echo "  ok: ~/.local/bin on PATH";; *) echo "  ACTION: add ~/.local/bin to PATH:  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc";; esac
echo "--- API keys (kept only in your shell rc; never copied by this installer)"
missing=0
d=$(keyval DEEPSEEK_API_KEY); o=$(keyval OPENROUTER_API_KEY)
if [ -n "$d" ]; then code=$(curl -s -o /dev/null -w '%{http_code}' -m 15 https://api.deepseek.com/models -H "Authorization: Bearer $d" || true); echo "  DEEPSEEK_API_KEY: present (api.deepseek.com/models -> HTTP $code)"; else missing=1; echo "  ACTION: DEEPSEEK_API_KEY missing. Create a key at https://platform.deepseek.com/api_keys, then:"; echo "      echo 'export DEEPSEEK_API_KEY=\"<your key>\"' >> ~/.bashrc && source ~/.bashrc"; fi
if [ -n "$o" ]; then code=$(curl -s -o /dev/null -w '%{http_code}' -m 15 https://openrouter.ai/api/v1/key -H "Authorization: Bearer $o" || true); echo "  OPENROUTER_API_KEY: present (openrouter.ai/api/v1/key -> HTTP $code)"; else missing=1; echo "  ACTION: OPENROUTER_API_KEY missing. Create a key at https://openrouter.ai/keys (set a spend limit; in Settings > Privacy block providers that train on prompts), then:"; echo "      echo 'export OPENROUTER_API_KEY=\"<your key>\"' >> ~/.bashrc && source ~/.bashrc"; fi
if [ $WATCHDOG = 1 ] && [ $CHECK = 0 ]; then
  if command -v systemctl >/dev/null; then D="$HOME/.config/systemd/user"; mkdir -p "$D"
    printf '[Unit]\nDescription=Lanes watchdog (kills clearly orphaned agent work)\n\n[Service]\nType=oneshot\nExecStart=/bin/bash -c "%s/lane/lane-watchdog.sh clean >> %s/.local/state/lanes-watchdog.log 2>&1"\n' "$K" "$HOME" > "$D/lanes-watchdog.service"
    printf '[Unit]\nDescription=Run the lanes watchdog at :17 and :47\n\n[Timer]\nOnCalendar=*-*-* *:17,47:00\n\n[Install]\nWantedBy=timers.target\n' > "$D/lanes-watchdog.timer"
    systemctl --user daemon-reload && systemctl --user enable --now lanes-watchdog.timer >/dev/null && echo "  watchdog timer enabled (log: ~/.local/state/lanes-watchdog.log)"
  else echo "  no systemd: run $K/lane/lane-watchdog.sh clean periodically (e.g. cron)"; fi
fi
if [ $SMOKE = 1 ] && [ $missing = 0 ]; then
  t=$(mktemp -d); cd "$t"
  for p in deepseek glm; do echo "--- smoke: $p"; echo 'Create s.py with sq(x) returning x*x, run python3 -c "from s import sq; print(sq(9))", and report the printed output.' | RELAY_WAIT_S=300 "$HOME/.local/bin/model-relay" "$p" | sed -n '2,6p'; done
  cd - >/dev/null; rm -rf "$t"
fi
echo "--- done. Restart Claude Code so the deepseek, glm, codex, opus-lane and sonnet-lane subagents load. Then use /lanes in any git project."
[ $missing = 0 ] || echo "!!! Add the missing API key(s) above, then re-run: bash $K/install.sh --smoke"
