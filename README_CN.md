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
- `hat` 只共享文件系统资产；它不会安装 CLI、执行技能脚本、管理插件/MCP 或浏览器登录。
- 一个角色在每个受支持 CLI 中始终拥有同一组技能。添加技能会先进行预检，再复制到该角色中，并以原子方式完成。
- `hat` 不会迁移、修复或扫描已有的 Claude/Codex/Qwen/Copilot 主目录；它只管理自己在 `HAT_HOME` 下创建的目录。

MCP 与插件被有意延后。文件凭据共享是显式选择：`hat` 可以将 Codex 和 Claude 的文件凭据路径链接到其默认主目录，但绝不读取或打印其内容。

## 安装

使用 curl 安装：

```sh
curl -fsSL https://hat.ffutop.com/install.sh | bash
```

安装程序会从 `https://hat.ffutop.com/bin/hat` 下载 `hat`，默认安装到 `~/.local/bin/hat`。设置 `PREFIX` 可选择其他当前用户可写的前缀。它不会修改 `.bashrc`、`.zshrc` 或其他 shell rc 文件。系统需要具备 `curl` 或 `wget` 之一。

如从本地检出版本安装，或需要使用固定版本/镜像，可通过 `HAT_DOWNLOAD_URL` 指向精确的 `bin/hat` 资源：

```sh
PREFIX="$HOME/.local" HAT_DOWNLOAD_URL="https://example.com/hat/bin/hat" ./install.sh
```

请确认所选 `bin` 目录已在 `PATH` 中，然后在当前 shell 中启用自动补全：

```sh
source <(hat completion bash)
# 或：source <(hat completion zsh)
```

如需让每个新开的 shell 都自动拥有补全，请改为写入 rc 文件：执行 `hat completion install bash` 或 `hat completion install zsh`，再重新加载对应 rc 文件（或新开一个终端）。该命令会追加一段带标记、幂等的代码块；重复执行不会产生重复内容。需要时，可在命令末尾传入 rc 文件的显式路径。

如需启用 `claude @角色` 和 `codex @角色` 快捷调用，请执行 `hat shortcut install bash` 或 `hat shortcut install zsh`，再重新加载对应 rc 文件。例如，`codex @architect` 会使用 `architect` 角色；`HAT_ROLE=architect codex` 可为单次调用指定角色。需要时，可在命令末尾传入 rc 文件的显式路径。

## 快速开始

```sh
# 创建隔离的角色；若角色已存在，此命令会失败。
hat role create architect

# 将标准技能包复制到角色中；源目录会保留。
hat role add-skill architect ~/work/skills/tdd tdd

# 显式将角色凭据文件链接到默认 CLI 主目录。
hat role share-auth architect

# 可选：为所有角色的 `hat run` 配置一个共享的 HTTP(S) 代理。
hat proxy set http://localhost:8008

# 在当前项目目录中运行已注册的 CLI。
hat run architect -- claude
hat run architect -- codex
hat run architect -- qwen
hat run architect -- copilot

# 只查看状态，不做任何修改。
hat role list
hat role doctor architect
hat proxy show
```

### 代理

`hat run` 会在启动 CLI 的这一次调用期间，导出已配置的代理——同时设置 `HTTP_PROXY`、`HTTPS_PROXY` 及其小写形式（不同 CLI 读取的大小写不一致），调用结束后不需要做任何恢复（每次 `hat run` 都是全新进程）。代理是所有角色共享的单一配置，而非按角色区分的状态；未配置时，`hat run` 完全不改动当前 shell 已有的代理环境变量。

```sh
hat proxy set <url>    # 例如 http://localhost:8008
hat proxy show
hat proxy unset
```

## 目录结构

`HAT_HOME` 是唯一的位置配置项，默认值为 `~/.hat`。

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

技能名称使用小写 slug（如 `tdd`、`report-review`）。`hat` 不提供删除命令。若要让角色停止使用某项技能，请仅手动移除该角色的本地技能目录。技能会独立复制到每个角色中；修改一个角色的副本不会影响其他角色。只有执行过 `hat proxy set` 之后，`~/.hat/proxy` 文件才会存在；它对所有角色生效。

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

## 共享文件凭据

`hat role share-auth <role> [codex|claude]` 会显式创建如下绝对软链。不传适配器参数时会同时创建两种链接。

| CLI | 角色文件 | 共享源 |
| --- | --- | --- |
| Codex | `<role>/adapters/codex/auth.json` | `~/.codex/auth.json` |
| Claude Code | `<role>/adapters/claude/.credentials.json` | `~/.claude/.credentials.json` |

若源文件不存在，`hat` 会先创建权限为 `0600` 的空文件，再将角色文件链接过去；已有源文件也会被收紧为 `0600`。这只是在准备共享位置，并不代表已登录；文件式 CLI 登录可经由该链接写入源文件，但 macOS 上 Claude 的正常登录仍写入 Keychain。已有的角色目标永不覆盖，`hat` 也不会读取或显示凭据内容。

Codex 当前会原地更新文件凭据，因此软链可形成一份共享的 `auth.json`。Claude Code 可能在 token 刷新时以替换目录项的方式更新 `.credentials.json`，从而使角色软链断开；refresh token 轮换也可能令其他文件共享者失效。因此 Claude 软链仅是尽力而为，不能用于并发会话，也不能替代 macOS Keychain 凭据。macOS 上 Claude 通常使用 Keychain，而非该文件。

## 开发

```sh
bash tests/run-tests.sh
bash -n bin/hat install.sh tests/run-tests.sh
```

测试套件使用临时的 `HAT_HOME` 和伪造的 CLI 二进制文件，不会触碰真实 CLI 的配置或凭据。

## 许可证

MIT。参见 [LICENSE](LICENSE)。
