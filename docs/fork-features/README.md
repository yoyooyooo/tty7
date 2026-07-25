# Fork 特性维护

该目录是 `yoyooyooo/tty7` 相对 `l0ng-ai/tty7` 的差异索引，供后续升级上游版本时判断哪些补丁应继续携带、已被上游吸收或可以退役。

## 边界

**Owns**

- fork 独有行为及其设计理由；
- fork 工具、代码锚点、验证命令和已知限制；
- 上游对应实现、Issue/PR、吸收状态和同步动作。

**Must Not Own**

- 上游 tty7 的完整产品说明；
- 没有代码或验证依据的完成声明；
- 临时实现步骤、聊天记录或通用 Git 教程。

代码与测试是当前行为的最高权威。本目录用于解释差异和同步生命周期；若文档与当前分支代码冲突，以代码为准并立即修正文档。

## 当前基线

| 项目 | 当前值 |
|---|---|
| 上游 | `l0ng-ai/tty7` |
| fork | `yoyooyooo/tty7` |
| 上游基线 | `upstream/main@673bdc9` |
| 当前自用分支 | `personal/meta-input` |
| 核心功能提交 | `1457c48` |
| 记录日期 | 2026-07-25 |

基线 SHA 只描述本次记录时的比较点。每次同步上游后必须更新本表和下方特性状态。

## 特性索引

| 特性 | 状态 | 当前承载位置 | 上游关系 |
|---|---|---|---|
| [未实现 Meta 键交给 PTY](meta-input-handoff.md) | `active-fork` | `personal/meta-input@1457c48` | 暂不提交上游 |
| [macOS 本地热替换工具](local-macos-install.md) | `active-fork-tooling` | `scripts/install-local-macos.sh` | 个人维护工具，不计划上游化 |
| [GUI 启动时 UTF-8 locale 兜底](macos-utf8-locale.md) | `upstream-pr` | `fix/macos-utf8-locale@d952294` | 上游 PR [#173](https://github.com/l0ng-ai/tty7/pull/173) |

状态含义：

- `active-fork`：当前自用分支中的行为差异；
- `active-fork-tooling`：只服务 fork 维护，不改变产品行为；
- `upstream-pr`：补丁位于独立分支并已提交上游，当前自用分支不因此自动具备该代码；
- `absorbed`：上游已有等价实现，下一次自用分支不再携带补丁；
- `retired`：明确放弃，文档保留退役理由。

## 上游同步流程

### 1. 更新上游镜像分支

```bash
git fetch upstream origin
git switch main
git merge --ff-only upstream/main
git push origin main
```

### 2. 检查每项 fork 差异

```bash
git log --oneline <旧上游基线>..upstream/main
git diff --stat upstream/main...personal/meta-input
```

逐项阅读本目录文档中的“上游同步检查”，判断：

1. 上游是否已有语义等价实现，而不只是相似命名；
2. 当前回归测试在新上游上是否仍成立；
3. 源码锚点是否移动；
4. 已知限制是否改变。

### 3. 构造下一版自用分支

为遵守 fast-forward-only、避免 merge 和改写已发布分支，建议从新上游基线创建版本化分支，再携带仍有效的 fork 提交：

```bash
git switch -c personal/meta-input-<upstream-version> upstream/main
git cherry-pick <仍需保留的fork提交>
```

验证并推送新分支后，更新本索引的“当前自用分支”“上游基线”“核心功能提交”。旧分支保留为历史证据，不作为下一轮开发入口。

### 4. 吸收或退役

- 上游等价实现通过本地验证：状态改为 `absorbed`，记录上游提交/版本，下一版不再 cherry-pick fork 补丁；
- 上游只部分覆盖：缩小 fork 补丁和文档，只保留剩余差异；
- 补丁不再需要：状态改为 `retired`，写明原因；
- 上游 PR 仍未处理：保持独立分支，不把候选补丁误记为当前自用分支能力。

## 验证入口

```bash
cargo fmt --check
cargo +1.97.1 test --locked option_as_alt
cargo +1.97.1 test --locked meta_chords_edit_locally_or_handoff_to_the_pty
bash -n scripts/install-local-macos.sh
```

产品行为仍需按各特性文档执行手工验证；单元测试不能替代真实 macOS Option 键、tmux 和已安装 APP 的端到端验证。
