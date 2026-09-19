# hat

[![OpenAI Codex](https://img.shields.io/badge/OpenAI_Codex-supported-412991?logo=openai&logoColor=white)](#adapters)
[![Claude Code](https://img.shields.io/badge/Claude_Code-supported-D97757?logo=anthropic&logoColor=white)](#adapters)

> **Role-scoped local profiles and skills for LLM tools.**

`hat` is a small, local, open-source tool for people who work through several stable roles—such as `engineer`, `economist`, `analyst`, and `technical writer`—while switching among LLM CLIs.

It keeps each role's skill packages inside that role's directory, then links the role-selected set into the configuration homes of Claude Code, Codex, Qwen Code, and GitHub Copilot CLI. `hat` does not choose a role for you: you name it each time you run a CLI.

![hat banner](assets/hat-banner.png)

```sh
hat run architect -- codex

# After `hat shortcut install bash` or `hat shortcut install zsh`:
codex @architect
```

## Scope

- A role is a stable work identity, not a model, reasoning mode, or task type.
- A skill is a directory containing `SKILL.md` and any scripts, references, or templates it needs.
- `hat` only shares filesystem assets. It does not install CLIs, execute skill scripts, manage plugins/MCP, or perform browser-based authentication.
- A role always has the same skill set across every supported CLI. Adding a skill copies it into that role after preflight, and completes atomically.
- `hat` never migrates, repairs, or scans existing Claude/Codex/Qwen/Copilot homes. It only manages directories that it creates under `HAT_HOME`.

MCP and plugins are deliberately deferred. Shared file credentials are an explicit opt-in: `hat` can link the Codex and Claude file credential paths to their default homes, but it never reads or prints their contents.

## Install

Install with curl:

```sh
curl -fsSL https://hat.ffutop.com/install.sh | bash
```

The installer downloads `hat` from `https://hat.ffutop.com/bin/hat` and installs it to `~/.local/bin/hat` by default. Set `PREFIX` to choose another user-writable prefix. It never changes `.bashrc`, `.zshrc`, or another shell rc file. It requires either `curl` or `wget`.

For a local checkout or a pinned/mirrored release, point `HAT_DOWNLOAD_URL` to the exact `bin/hat` asset:

```sh
PREFIX="$HOME/.local" HAT_DOWNLOAD_URL="https://example.com/hat/bin/hat" ./install.sh
```

Ensure the chosen `bin` directory is on `PATH`, then enable completion for the current shell:

```sh
source <(hat completion bash)
# or: source <(hat completion zsh)
```

To keep completion available in every new shell, install it into the rc file instead: run `hat completion install bash` or `hat completion install zsh`, then reload the corresponding rc file (or open a new one). It appends an idempotent, marker-delimited block; running it again is a no-op. Pass an explicit rc-file path as the final argument when needed.

To enable `claude @role` and `codex @role` shortcuts, run `hat shortcut install bash` or `hat shortcut install zsh`, then reload the corresponding rc file. For example, `codex @architect` uses the `architect` role; `HAT_ROLE=architect codex` sets the role for one invocation. Pass an explicit rc-file path as the final argument when needed.

## Quick start

```sh
# Create an isolated role. This fails if the role already exists.
hat role create architect

# Copy a standard skill package into the role. Source is retained.
hat role add-skill architect ~/work/skills/tdd tdd

# Explicitly link role credential files to the default CLI homes.
hat role share-auth architect

# Optionally set a shared HTTP(S) proxy for every role's `hat run`.
hat proxy set http://localhost:8008

# Run a registered CLI in the current project directory.
hat run architect -- claude
hat run architect -- codex
hat run architect -- qwen
hat run architect -- copilot

# Inspect state without changing it.
hat role list
hat role doctor architect
hat proxy show
```

### Proxy

`hat run` exports the configured proxy — as `HTTP_PROXY`, `HTTPS_PROXY`, and their lowercase forms, since CLIs disagree on which case they read — for the duration of the command it launches, then restores nothing (each `hat run` is a fresh process). The proxy is a single, shared setting for every role, not per-role state; when unset, `hat run` leaves the ambient shell's proxy variables untouched.

```sh
hat proxy set <url>    # e.g. http://localhost:8008
hat proxy show
hat proxy unset
```

## Layout

`HAT_HOME` is the only location setting. It defaults to `~/.hat`.

```text
~/.hat/
├── proxy
└── architect/
    ├── .hat-role
    ├── skills/
    │   └── tdd/
    │       ├── .hat-skill
    │       └── SKILL.md
    └── adapters/
        ├── claude/skills -> ../../skills
        ├── codex/skills -> ../../skills
        ├── qwen/skills -> ../../skills
        └── copilot/skills -> ../../skills
```

Skill names use lower-case slugs (`tdd`, `report-review`). `hat` does not offer deletion commands. To stop a role from using a skill, manually remove that role's local skill directory. Skills are copied independently into each role; changing one role's copy does not change another's. `~/.hat/proxy` only exists once `hat proxy set` has been run; it applies to every role.

## Adapters

`hat run` accepts only registered adapter names and preserves the caller's current directory and ordinary environment. It adds only the adapter's config-home variable:

| CLI | Environment variable | Role discovery directory |
| --- | --- | --- |
| Claude Code | `CLAUDE_CONFIG_DIR` | `<role>/adapters/claude/skills` |
| Codex | `CODEX_HOME` | `<role>/adapters/codex/skills` |
| Qwen Code | `QWEN_HOME` | `<role>/adapters/qwen/skills` |
| GitHub Copilot CLI | `COPILOT_HOME` | `<role>/adapters/copilot/skills` |

Qwen Code documents `QWEN_HOME` as its configurable global home, including global skills. GitHub Copilot CLI documents `COPILOT_HOME` and personal `skills/<name>/SKILL.md` locations. Check the adapter’s current compatibility note before relying on a new CLI release. [Qwen Code configuration](https://qwenlm.github.io/qwen-code-docs/en/users/configuration/settings/) · [Copilot CLI skills](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)

`hat role doctor` verifies the role marker, every adapter discovery link, and every locally copied skill package. It also performs a local `--version` query when an adapter is installed; a missing adapter is a warning because roles can be prepared before every CLI is installed. It never starts an interactive session, authenticates, or contacts a network service.

## Shared file credentials

`hat role share-auth <role> [codex|claude]` explicitly creates the following absolute symlinks. With no adapter argument it creates both.

| CLI | Role file | Shared source |
| --- | --- | --- |
| Codex | `<role>/adapters/codex/auth.json` | `~/.codex/auth.json` |
| Claude Code | `<role>/adapters/claude/.credentials.json` | `~/.claude/.credentials.json` |

If a source file is absent, `hat` creates an empty, mode-`0600` file and then links the role file to it; existing source files are also restricted to mode `0600`. This only prepares the shared location; it does not log in. A later file-backed CLI login may populate the source through the link, but a normal macOS Claude login writes Keychain instead. Existing role targets are never replaced, and `hat` never reads or displays credential contents.

Codex currently updates its file credential in place, so the symlink provides one shared `auth.json`. Claude Code may update `.credentials.json` by replacing its directory entry during token refresh; that can detach the role symlink and refresh-token rotation can invalidate other file sharers. The Claude link is therefore best-effort and must not be used for concurrent sessions or as a substitute for macOS Keychain credentials. On macOS, Claude normally uses Keychain rather than this file.

## Development

```sh
bash tests/run-tests.sh
bash -n bin/hat install.sh tests/run-tests.sh
```

The test suite uses a temporary `HAT_HOME` and fake CLI binary. It does not touch real CLI configuration or credentials.

## License

MIT. See [LICENSE](LICENSE).
