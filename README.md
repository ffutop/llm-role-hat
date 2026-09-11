# hat

![hat banner](assets/hat-banner.png)

`hat` is a small, local, open-source tool for people who work through several stable roles—such as `engineer`, `economist`, `analyst`, and `technical writer`—while switching among LLM CLIs.

It keeps each role's skill packages inside that role's directory, then links the role-selected set into the configuration homes of Claude Code, Codex, Qwen Code, and GitHub Copilot CLI. `hat` does not choose a role for you: you name it each time you run a CLI.

```sh
hat run architect -- codex

# After `hat shortcut install bash` or `hat shortcut install zsh`:
codex @architect
```

## Scope

- A role is a stable work identity, not a model, reasoning mode, or task type.
- A skill is a directory containing `SKILL.md` and any scripts, references, or templates it needs.
- `hat` only shares filesystem assets. It does not install CLIs, execute skill scripts, manage plugins/MCP, or manage credentials.
- A role always has the same skill set across every supported CLI. Adding a skill copies it into that role after preflight, and completes atomically.
- `hat` never migrates, repairs, or scans existing Claude/Codex/Qwen/Copilot homes. It only manages directories that it creates under `HAT_HOME`.

MCP, plugins, and shared authentication are deliberately deferred. They may be added only if a future adapter can prove that they are safely shareable as filesystem assets without changing this boundary.

## Install

Clone this repository, then run:

```sh
./install.sh
```

The installer copies `hat` to `~/.local/bin/hat` by default. Set `PREFIX` to choose another user-writable prefix. It never changes `.bashrc`, `.zshrc`, or another shell rc file.

Ensure the chosen `bin` directory is on `PATH`, then optionally enable completion:

```sh
source <(hat completion bash)
# or: source <(hat completion zsh)
```

To enable `claude @role` and `codex @role` shortcuts, run `hat shortcut install bash` or `hat shortcut install zsh`, then reload the corresponding rc file. For example, `codex @architect` uses the `architect` role; `HAT_ROLE=architect codex` sets the role for one invocation. Pass an explicit rc-file path as the final argument when needed.

## Quick start

```sh
# Create an isolated role. This fails if the role already exists.
hat role create architect

# Copy a standard skill package into the role. Source is retained.
hat role add-skill architect ~/work/skills/tdd tdd

# Run a registered CLI in the current project directory.
hat run architect -- claude
hat run architect -- codex
hat run architect -- qwen
hat run architect -- copilot

# Inspect state without changing it.
hat role list
hat role doctor architect
```

## Layout

`HAT_HOME` is the only location setting. It defaults to `~/.hat`.

```text
~/.hat/
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

Skill names use lower-case slugs (`tdd`, `report-review`). `hat` does not offer deletion commands. To stop a role from using a skill, manually remove that role's local skill directory. Skills are copied independently into each role; changing one role's copy does not change another's.

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

## Development

```sh
bash tests/run-tests.sh
bash -n bin/hat install.sh tests/run-tests.sh
```

The test suite uses a temporary `HAT_HOME` and fake CLI binary. It does not touch real CLI configuration or credentials.

## License

MIT. See [LICENSE](LICENSE).
