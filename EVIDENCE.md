# Evidence — Neon Climber, built by an OPEN model across 6 governed batches

This records the actual run, so *"coded by gpt-oss-120b on watsonx, under a Matrix Builder
contract"* is verifiable rather than asserted.

## Environment

| | |
|---|---|
| Contract engine | `agent-generator` 0.2.0 (the `mb` CLI) |
| Coder driver | GitPilot (`gitcopilot`) — `gitpilot generate`, `GITPILOT_PROVIDER=watsonx` |
| LLM provider | **IBM watsonx.ai** (`us-south.ml.cloud.ibm.com`) |
| Model | **`openai/gpt-oss-120b`** (OpenAI open-weight, ~117B, high-reasoning) |
| Endpoint | `/ml/v1/text/chat` (OpenAI-compatible chat, via litellm) |

> Note: the rest of the arcade (Pong, Tetris, Match-3) was built with Claude Opus 4.8. This
> game was built with a different model through the **same** contract loop — the point being
> that Matrix Builder's governance is provider-agnostic.

## The 6 batches

Each batch ran: `mb next` → `mb prompt --coder gitpilot` → `gitpilot generate` (gpt-oss-120b,
given the contract + the current file + the batch spec) → `mb check`. The allow-list for every
batch was **`frontend/index.html` only**; the model never wrote outside it.

| # | Batch | Result file | `mb check` | Matrix Commit |
|---|---|---|---|---|
| 1 | Foundation (hero, jump physics, vertical camera, procedural platforms) | 15,424 B | approved · 100 | `mc-f0101634a883` |
| 2 | Controls (left/right, screen-wrap, tilt + touch + keyboard) | 22,366 B | approved · 100 | `mc-2cde9611b371` |
| 3 | Platforms + collectibles (moving/breaking/spring, coins + stars) | 36,421 B | approved · 100 | `mc-511e55820933` |
| 4 | Enemies + power-ups (stomp, shield / jetpack / magnet) | 35,433 B | approved · 100 | `mc-cf84ff722c6e` |
| 5 | Juice (particles, trail, parallax, WebAudio, screen-shake) | 41,405 B | approved · 100 | `mc-b133e1b1d466` |
| 6 | Meta (start / game-over, high score, difficulty, boss milestone) | 47,480 B | approved · 100 | `mc-8c08092f78c3` |

## A representative batch (Batch 6 — meta)

```text
$ export GITPILOT_PROVIDER=watsonx GITPILOT_WATSONX_MODEL=openai/gpt-oss-120b
$ export WATSONX_API_KEY=…  WATSONX_PROJECT_ID=…  WATSONX_URL=https://us-south.ml.cloud.ibm.com
$ mb next "Meta: start, game-over, high score, difficulty, boss"
$ mb prompt --coder gitpilot
$ gitpilot generate -m "$(cat coder-prompts/gitpilot.md) + current file + batch spec" -o .
Provider: watsonx
  Created: frontend/index.html (47445 bytes)
$ mb check frontend/index.html
MATRIX_STATUS: approved  score=100
  committed mc-8c08092f78c3
```

## Independent checks

- After **every** batch: extracted `<script>` passed `node --check`, the file ended with a
  complete `</html>`, and accumulated features from earlier batches were re-verified present
  (no regressions despite full-file rewrites).
- Final headless-Chromium smoke test: **zero runtime errors**; start screen, climbing,
  enemies, power-ups, high score (BEST) and the footer credit all work.

## Tooling notes

- GitPilot's watsonx provider hard-capped `max_tokens=1024`; a configurable `GITPILOT_MAX_TOKENS`
  was added to `gitpilot/llm_provider.py` (branch `fix/anthropic-max-tokens`) so full-file
  generations aren't truncated.
- Prompts instructed the model to emit a single fenced code block with no diff markers, which
  kept GitPilot's file extractor clean.
- The watsonx API key used was temporary and has been rotated.
