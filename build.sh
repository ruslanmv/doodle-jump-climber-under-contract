#!/usr/bin/env bash
# =============================================================================
# Neon Climber — Under Contract :: reproducible build script
# -----------------------------------------------------------------------------
# Rebuilds the ENTIRE game from scratch the way it was originally made:
# 6 governed Matrix Builder batches, each coded by an LLM through GitPilot and
# validated by `mb check` before it is allowed to land.
#
# This run uses IBM watsonx.ai with the open model `openai/gpt-oss-120b`, but
# the workflow is provider-agnostic — set GITPILOT_PROVIDER + the matching env
# vars to use Claude, OpenAI, or local Ollama instead. The contracts don't change.
#
# Prerequisites:
#   pip install agent-generator gitcopilot crewai
#   node (optional, for the JS syntax check)
#   WATSONX_API_KEY and WATSONX_PROJECT_ID exported in your shell
#
# Usage:
#   export WATSONX_API_KEY=...                # your IBM Cloud API key
#   export WATSONX_PROJECT_ID=...             # your watsonx project id
#   ./build.sh                                # builds into ./frontend/index.html
# =============================================================================
set -euo pipefail

# ── Provider configuration (watsonx + gpt-oss-120b) ──────────────────────────
: "${WATSONX_API_KEY:?Set WATSONX_API_KEY (your IBM Cloud API key)}"
: "${WATSONX_PROJECT_ID:?Set WATSONX_PROJECT_ID (your watsonx project id)}"
export GITPILOT_PROVIDER="${GITPILOT_PROVIDER:-watsonx}"
export WATSONX_URL="${WATSONX_URL:-https://us-south.ml.cloud.ibm.com}"
export WATSONX_BASE_URL="$WATSONX_URL"
export GITPILOT_WATSONX_MODEL="${GITPILOT_WATSONX_MODEL:-openai/gpt-oss-120b}"
export GITPILOT_MAX_TOKENS="${GITPILOT_MAX_TOKENS:-18000}"   # raise the default 1024 cap
export OTEL_SDK_DISABLED=true CREWAI_DISABLE_TELEMETRY=true LITELLM_LOG=ERROR

IDEA="A neon Mario-style vertical platformer / Doodle-Jump climber, single self-contained HTML file, runs on GitHub Pages, mobile + desktop"
PROJECT_TITLE="Neon Climber Under Contract"
ALLOWED="frontend/index.html"

# ── The 6 batch goals ────────────────────────────────────────────────────────
GOALS=(
  "Foundation: neon hero, jump physics, vertical camera, procedural platforms"
  "Controls and horizontal movement"
  "Platform types and collectibles"
  "Enemies and power-ups"
  "Juice: particles, parallax, sound, screen-shake"
  "Meta: start, game-over, high score, difficulty, boss"
)

# ── The 6 batch specs (what the model is asked to add each batch) ─────────────
SPECS=(
"Build the FOUNDATION of a polished NEON Mario-style vertical platformer (Doodle-Jump-style climber) in ONE self-contained frontend/index.html (inline CSS+JS, no external libraries, runs on GitHub Pages, mobile + desktop, portrait). Responsive DPR-aware <canvas> on a dark neon gradient with a starfield/grid; a small glowing neon HERO affected by gravity; Doodle-Jump auto-bounce on landing; PROCEDURALLY generated, always-reachable platforms; a vertical follow-camera; a HEIGHT score HUD; and a footer reading exactly: coded by GitPilot - under a Matrix Builder contract. Clean modular functions so later batches extend without rewrites."

"Add horizontal CONTROLS: smooth left/right movement via keyboard (arrows + A/D), MOBILE TILT (deviceorientation, with iOS permission), and TOUCH (hold/drag left or right half). The hero WRAPS around the screen edges and leans toward travel. Keep auto-bounce, follow-camera, procedural platforms and height score intact; make it responsive on phone and desktop."

"Add PLATFORM VARIETY and COLLECTIBLES, mixed into procedural generation while staying beatable: static, MOVING, BREAKING/crumbling (collapse after a bounce), one-shot disappearing, and SPRING/trampoline pads (super-bounce). Floating COIN orbs and rarer STARS worth points, with pickup popups and a coin HUD counter. Keep all movement, controls, camera, wrapping and generation intact."

"Add ENEMIES and POWER-UPS. Enemies: small neon goombas; landing on one from ABOVE stomps it for points + a bounce; a side/below hit without protection hurts the hero (flash + knockback + brief invulnerability). Power-ups as floating pickups with icons, timers and active indicators: SHIELD (invincibility), JETPACK/ROCKET (sustained boost), MAGNET (attracts coins/stars), optional DOUBLE-JUMP. Keep all platforms, collectibles, controls, camera and generation intact and balanced."

"Add JUICE: particle effects (coin sparkle, enemy-stomp burst, spring puff, power-up shimmer, landing dust), a glowing hero TRAIL, a PARALLAX neon background, SCREEN-SHAKE on big events, eased camera, and WebAudio SOUND effects (bounce, coin, power-up, stomp, spring, hurt) with a MUTE toggle. Honor prefers-reduced-motion. Keep ALL gameplay intact."

"Add META progression and screens: a START/title screen with a one-line how-to and Press/Tap to start; GAME OVER when the hero falls below the view or is hit without protection (final + best height, Tap/Enter to restart); HIGH SCORE in localStorage shown in the HUD; a difficulty ramp; a BOSS milestone every ~1500 height; clean restart; accessibility (aria-label, reduced motion). Footer must read exactly: coded by GitPilot - under a Matrix Builder contract. Keep ALL gameplay intact; ensure title -> playing -> game over -> restart transitions are correct."
)

# ── Helper: scope the active batch's allow-list to the single game file ───────
tailor() {  # $1 = NN (zero-padded batch), $2 = title
  python3 - "$1" "$2" <<'PY'
import json, sys
p = ".mb/batches/%s/batch.json" % sys.argv[1]
d = json.load(open(p)); files = ["frontend/index.html"]
d["plan"]["allowed_files"] = files
d["plan"]["tasks"][0]["allowed_files"] = files
d["plan"]["tasks"][0]["title"] = sys.argv[2]
d["plan"]["title"] = sys.argv[2]; d["title"] = sys.argv[2]
json.dump(d, open(p, "w"), indent=2)
PY
}

# ── Helper: assemble the per-batch message (contract + current file + spec) ───
assemble() {  # $1 = NN, $2 = "Batch i of 6", reads $SPEC env
  python3 - "$1" "$2" <<'PY'
import os, sys
NN, label = sys.argv[1], sys.argv[2]
contract = open("coder-prompts/gitpilot.md").read()
try:
    cur = open("frontend/index.html").read()
    body = ("\n\nYou are EXTENDING an existing single-file game. Keep ALL existing "
            "functionality; only ADD this batch's features. Current full content "
            "between markers:\n<<<CURRENT_FILE>>>\n%s\n<<<END_FILE>>>\n" % cur)
except FileNotFoundError:
    body = "\n\nThis is the first batch; create the file from scratch.\n"
spec = os.environ["SPEC"]
msg = (f"{contract}{body}\nTASK ({label}): {spec}\n\n"
       "Output the COMPLETE frontend/index.html (the entire file). Use EXACTLY this "
       "opening fence on its own line: three backticks then `html frontend/index.html`, "
       "then the full file, then a closing three-backtick fence. Output ONLY that one "
       "code block — no diff markers, no '---' lines, no explanations.")
open("/tmp/mb_msg.txt", "w").write(msg)
PY
}

# ── Build ────────────────────────────────────────────────────────────────────
echo "▶ Provider: $GITPILOT_PROVIDER · Model: $GITPILOT_WATSONX_MODEL"
echo "▶ mb init…"
mb init "$IDEA" --quality standard --title "$PROJECT_TITLE"

for i in 1 2 3 4 5 6; do
  NN=$(printf "%02d" "$i")
  GOAL="${GOALS[$((i-1))]}"
  export SPEC="${SPECS[$((i-1))]}"
  echo "──────────────────────────────────────────────────────────"
  echo "▶ Batch $i/6 — $GOAL"
  mb next "$GOAL"            > /dev/null
  tailor "$NN" "$GOAL"
  mb prompt --coder gitpilot > /dev/null
  cp ".mb/batches/$NN/prompts/gitpilot.md" coder-prompts/gitpilot.md 2>/dev/null || \
     { mkdir -p coder-prompts; cp ".mb/batches/$NN/prompts/gitpilot.md" coder-prompts/gitpilot.md; }
  assemble "$NN" "Batch $i of 6"
  gitpilot generate -m "$(cat /tmp/mb_msg.txt)" -o .
  mb check "$ALLOWED"
  # quick integrity check
  python3 - <<'PY'
import re
h = open("frontend/index.html").read()
m = re.search(r"<script[^>]*>(.*?)</script>", h, re.S)
open("/tmp/_g.js", "w").write(m.group(1) if m else "")
assert h.rstrip().endswith("</html>"), "TRUNCATED: no closing </html>"
print("   ✓ %d bytes, closing </html> present" % len(h))
PY
  command -v node >/dev/null && { node --check /tmp/_g.js && echo "   ✓ JS syntax OK"; }
done

echo "──────────────────────────────────────────────────────────"
echo "✅ Build complete → frontend/index.html"
echo "   Run it locally:  python3 -m http.server -d frontend 8080  →  http://localhost:8080"
echo "   Audit the run:   mb timeline"
