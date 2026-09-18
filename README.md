# Devbox — Opencode Agent Sandbox

A reproducible, Docker-based development container for running [opencode](https://opencode.ai) with a lean toolchain for Python, Node.js, and Java (via SDKMAN!) — plus web search via Exa MCP and models via OpenRouter.

Drop into `/workspace` inside the container and let the agent build with you. The host `./workspace` folder is your shared scratch space, and agent sessions/state persist per-folder in `.opencode-state`.

## What's inside

**Base:** Ubuntu 24.04 + `build-essential`, `curl`, `git`, `ca-certificates`, `zip`, `unzip`

**Toolchains (installed in image):**
- Python 3 + pip + venv
- Node.js + npm (Ubuntu repo)
- SDKMAN! as the `dev` user with **no pre-installed JDKs** — install on demand so the image stays small:
  ```bash
  sdk list java
  sdk install java 21-tem && sdk default java 21-tem
  ```
- Java build tools are intentionally omitted — projects should use Maven/Gradle wrappers (`./mvnw`, `./gradlew`)

**Agent:**
- `opencode` installed system-wide to `/usr/local/bin/opencode`
- Default config in `opencode.json` → copied to `/home/dev/.config/opencode/opencode.json` at build time, and bind-mounted read-only at runtime
- Default model: `openrouter/openai/gpt-5.6-luna`
- MCP server: Exa (`https://mcp.exa.ai/mcp`) for web search, auth via `EXA_API_KEY`

**Runtime user:** `dev` (non-root), home `/home/dev`, workdir `/workspace`

## Project structure

```text
.
├── Dockerfile           # agent sandbox image definition
├── docker-compose.yml   # agent-sandbox service, mounts, env, command
├── opencode.json        # opencode model + MCP config (mounted read-only)
├── .env.example         # template for required API keys (copy to .env)
├── .dockerignore
├── .gitignore
├── workspace/           # mounted to /workspace — ephemeral agent scratch space
│   └── ...              # your project files live here
└── .opencode-state/     # persisted opencode sessions/auth/logs (bind mount to ~/.local)
```

> `workspace/` and `.opencode-state/` are git-ignored by design. Copying this whole folder gives you an isolated sandbox whose state travels with it.

## Prerequisites

1. **Docker Desktop** (or Docker Engine + Compose v2) installed and running.
   - Verify with `docker --version` and `docker compose version`
2. **API keys:**
   - [OpenRouter](https://openrouter.ai) key → `OPENROUTER_API_KEY`
   - [Exa](https://exa.ai) key → `EXA_API_KEY`

## Quickstart — start the container

1. **Configure secrets:**

   ```bash
   cp .env.example .env
   ```

   Then edit `.env` and fill in real values:

   ```ini
   EXA_API_KEY=your-exa-key-here
   OPENROUTER_API_KEY=your-openrouter-key-here
   ```

   > Never commit `.env`. It's already in `.gitignore` and `.dockerignore`.

2. **Build and start (attached, interactive):**

   ```bash
   docker compose run --build --rm agent-sandbox
   ```

   This builds a one-off container, mounts `./workspace` → `/workspace`, mounts `opencode.json` read-only, persists state to `./.opencode-state`, and runs `opencode --auto` as the `dev` user with an interactive terminal. The one-off container is removed when OpenCode exits.

   You should land directly in an opencode session inside the container. `Ctrl+C` stops the agent; the container stops with it.

3. **Run in the background instead:**

   ```bash
   docker compose up --build -d
   docker attach devbox-agent-sandbox-1
   # or open a shell:
   docker compose exec agent-sandbox bash
   ```

4. **Stop / clean up:**

   ```bash
   docker compose down        # stop containers
   docker compose down --rmi local  # also remove the built image
   ```

## Daily usage

| Task | Command |
|------|---------|
| Start agent (foreground) | `docker compose run --rm agent-sandbox` |
| Rebuild after Dockerfile change | `docker compose run --build --rm agent-sandbox` |
| Shell as `dev` user | `docker compose exec agent-sandbox bash` |
| Shell as root (install sys pkgs) | `docker compose exec -u root agent-sandbox bash` |
| View logs | `docker compose logs -f agent-sandbox` |
| Run one-off command | `docker compose run --rm agent-sandbox python3 --version` |
| Install a JDK (in container) | `sdk install java 21-tem && sdk default java 21-tem` |

### Working with the workspace

- Edit files on the host in `./workspace/` — they appear live at `/workspace` in the container.
- Example: install a JDK for the project you're working on:

  ```bash
  # inside the container
  sdk list java
  sdk install java 21-tem
  sdk default java 21-tem
  java -version
  # build with ./mvnw / ./gradlew wrappers — no system Maven/Gradle needed
  ```

### Exposing ports (web apps)

The default `docker-compose.yml` exposes **no ports**. If your workspace app serves HTTP (e.g. Signal BBS on `:3000`), add a `ports` mapping:

```yaml
services:
  agent-sandbox:
    ports:
      - "3000:3000"
```

Then restart with `docker compose up`. For additional apps, add more entries (e.g. `"8080:8080"`).

### Changing the model / config

1. Edit `opencode.json` on the host — it's bind-mounted read-only, so just restart the container to pick up changes:
   ```bash
   docker compose restart agent-sandbox
   ```
2. To add MCP servers or change permissions, follow the [opencode config docs](https://opencode.ai/docs/config) — same schema.

### State persistence

`./.opencode-state` is bind-mounted to `/home/dev/.local` (XDG state dir) so sessions, auth, and logs survive restarts and travel with the folder. To start fresh:

```bash
docker compose down
rm -rf .opencode-state/*
docker compose up
```

## Troubleshooting

- **Agent exits immediately / can't type:** the service needs a TTY (`stdin_open: true`, `tty: true` are already set). Use `docker compose up` (not `up -d`) or `docker attach` to interact.
- **`OPENROUTER_API_KEY` / `EXA_API_KEY` empty:** make sure `.env` exists next to `docker-compose.yml` and has no quotes/spaces around values. Compose also passes them via `env_file` + `environment`.
- **Permission errors in `~/.local`:** the compose file intentionally mounts at `.local` (not `share/opencode`) so the daemon doesn't create root-owned parent dirs. If you changed the mount, `chown -R $(id -u):$(id -g) .opencode-state` on the host, or `docker compose exec -u root agent-sandbox chown -R dev:dev /home/dev/.local`.
- **`opencode.json` changes not applying:** it's mounted `:ro` — restart the service; don't edit the in-container copy.
- **Slow first build:** apt packages and `opencode` download on first build. Subsequent builds are cached unless the `Dockerfile` changes. (JDKs download on demand via SDKMAN!, per container.)

## Security notes

- `.env` holds real keys — never commit it, never bake it into the image.
- The agent runs as non-root `dev`, with `permission: allow` in `opencode.json` — review before pointing it at sensitive repos.
- The Exa MCP server calls a remote URL and sends your `EXA_API_KEY` header — disable it in `opencode.json` (`"enabled": false`) if you don't need web search.

## License

No license specified. Add one if you plan to share this (e.g. MIT).
