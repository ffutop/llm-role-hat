# hat

[![OpenAI Codex](https://img.shields.io/badge/OpenAI_Codex-supported-412991?logo=openai&logoColor=white)](#适配器)
[![Claude Code](https://img.shields.io/badge/Claude_Code-supported-D97757?logo=anthropic&logoColor=white)](#适配器)

> **面向大语言模型工具的、按角色隔离的本地配置与技能。**

`hat` 是一个小巧、本地、开源的工具，面向会在多个稳定角色（如工程师、经济师、分析师和技术写作者）之间工作、同时切换不同 LLM CLI 的用户。

它将每个角色的技能包保存在该角色自己的目录中，再把该角色选定的技能集链接到 Claude Code、Codex、Qwen Code 和 GitHub Copilot CLI 的配置目录。`hat` 不会替你选择角色：每次运行 CLI 时，都由你明确指定。

![hat banner](assets/hat-banner.png)

```sh
hat run architect -- codex

# 执行 `hat shortcut install bash` 或 `hat shortcut install zsh` 后：
codex @architect
```

## 范围

- 角色是稳定的工作身份，不是模型、推理模式或任务类型。
- 技能是一个包含 `SKILL.md` 及其所需脚本、参考资料或模板的目录。
- `hat` 只共享文件系统资产；它不会安装 CLI、执行技能脚本、管理插件/MCP 或管理凭据。
- 一个角色在每个受支持 CLI 中始终拥有同一组技能。添加技能会先进行预检，再复制到该角色中，并以原子方式完成。
- `hat` 不会迁移、修复或扫描已有的 Claude/Codex/Qwen/Copilot 主目录；它只管理自己在 `HAT_HOME` 下创建的目录。

MCP、插件和共享认证被有意延后处理。只有当未来的适配器能够证明它们可作为文件系统资产安全共享、且不突破上述边界时，才会考虑加入。

## 安装

克隆本仓库后，运行：

```sh
./install.sh
```

安装程序默认将 `hat` 复制到 `~/.local/bin/hat`。设置 `PREFIX` 可选择其他当前用户可写的前缀。它不会修改 `.bashrc`、`.zshrc` 或其他 shell rc 文件。

请确认所选 `bin` 目录已在 `PATH` 中，然后可选地启用自动补全：

```sh
source <(hat completion bash)
# 或：source <(hat completion zsh)
```

如需启用 `claude @角色` 和 `codex @角色` 快捷调用，请执行 `hat shortcut install bash` 或 `hat shortcut install zsh`，再重新加载对应 rc 文件。例如，`codex @architect` 会使用 `architect` 角色；`HAT_ROLE=architect codex` 可为单次调用指定角色。需要时，可在命令末尾传入 rc 文件的显式路径。

## 快速开始

```sh
# 创建隔离的角色；若角色已存在，此命令会失败。
hat role create architect

# 将标准技能包复制到角色中；源目录会保留。
hat role add-skill architect ~/work/skills/tdd tdd

# 在当前项目目录中运行已注册的 CLI。
hat run architect -- claude
hat run architect -- codex
hat run architect -- qwen
hat run architect -- copilot

# 只查看状态，不做任何修改。
hat role list
hat role doctor architect
```

## 目录结构

`HAT_HOME` 是唯一的位置配置项，默认值为 `~/.hat`。

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

技能名称使用小写 slug（如 `tdd`、`report-review`）。`hat` 不提供删除命令。若要让角色停止使用某项技能，请仅手动移除该角色的本地技能目录。技能会独立复制到每个角色中；修改一个角色的副本不会影响其他角色。

## 适配器

`hat run` 只接受已注册的适配器名称，并会保留调用者的当前目录和普通环境变量；它只添加适配器对应的配置主目录变量：

| CLI | 环境变量 | 角色发现目录 |
| --- | --- | --- |
| Claude Code | `CLAUDE_CONFIG_DIR` | `<role>/adapters/claude/skills` |
| Codex | `CODEX_HOME` | `<role>/adapters/codex/skills` |
| Qwen Code | `QWEN_HOME` | `<role>/adapters/qwen/skills` |
| GitHub Copilot CLI | `COPILOT_HOME` | `<role>/adapters/copilot/skills` |

Qwen Code 将 `QWEN_HOME` 说明为可配置的全局主目录，其中包括全局技能。GitHub Copilot CLI 说明了 `COPILOT_HOME` 以及个人 `skills/<name>/SKILL.md` 位置。在依赖某个新 CLI 版本之前，请先查看该适配器最新的兼容性说明。[Qwen Code 配置](https://qwenlm.github.io/qwen-code-docs/en/users/configuration/settings/) · [Copilot CLI 技能](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)

`hat role doctor` 会验证角色标记、每个适配器的发现链接以及每个本地复制的技能包。若已安装适配器，它还会在本地执行一次 `--version` 查询；缺少适配器只会产生警告，因为可以在所有 CLI 安装完成前预先准备角色。它不会启动交互式会话、进行认证或连接网络服务。

## 开发

```sh
bash tests/run-tests.sh
bash -n bin/hat install.sh tests/run-tests.sh
```

测试套件使用临时的 `HAT_HOME` 和伪造的 CLI 二进制文件，不会触碰真实 CLI 的配置或凭据。

## 许可证

MIT。参见 [LICENSE](LICENSE)。
