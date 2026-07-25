# macOS GUI 启动时 UTF-8 locale 兜底

## 状态

- 生命周期：`upstream-pr`
- 独立分支：`fix/macos-utf8-locale`
- 最新提交：`d952294 fix(config): respect explicit locale overrides`
- 上游 PR：[l0ng-ai/tty7#173](https://github.com/l0ng-ai/tty7/pull/173)
- 当前自用分支：未包含该源码补丁
- 本机临时生效方式：`~/.config/tty7/config.json` 中设置 `LC_CTYPE=UTF-8`

该文档记录候选补丁和同步状态，不得据此声称 `personal/meta-input` 已经包含源码级 locale 兜底。

## 根因

通过 Finder/Dock 启动的 tty7 GUI 和其 detached daemon 可能完全没有：

```text
LC_ALL
LC_CTYPE
LANG
```

直接 shell 通常仍能输出 UTF-8，但 tmux client 会根据 locale 判断 UTF-8 能力。三者均缺失时，tmux 不设置 `CLIENT_UTF8`，并会把非 ASCII display cell 替换为 `_`。因此症状表现为：tty7 直接使用中文正常，进入 tmux 后中文变成连续下划线。

## 候选修复

独立分支中的补丁在 macOS shell spawn 路径执行条件兜底：

```text
用户配置了任意 locale key（包括空值） → 完全尊重 Config
继承环境已有非空 locale                → 完全尊重继承值
两者都没有                             → 注入 LC_CTYPE=UTF-8
```

只设置 `LC_CTYPE`，避免擅自改变消息、日期、数字等区域设置；不静态写入 Config 默认值，也不假定用户属于 `en_US` 或 `zh_CN`。

## 源码与测试锚点

该补丁不在当前自用分支中，需切换独立分支查看。首次在本 clone 中使用时建立远程跟踪分支：

```bash
git switch --track origin/fix/macos-utf8-locale
```

若本地分支已经存在，直接执行 `git switch fix/macos-utf8-locale`。

锚点：

- `src/daemon/pane.rs`：`locale_fallback_is_needed`；
- `src/daemon/pane.rs`：`apply_common_command_setup` 中 macOS fallback；
- `src/daemon/pane.rs`：`locale_fallback_respects_inherited_and_configured_environments`；
- `CHANGELOG.md`：`[Unreleased]` 下对应修复说明。

远程源码：[`fix/macos-utf8-locale/src/daemon/pane.rs`](https://github.com/yoyooyooo/tty7/blob/fix/macos-utf8-locale/src/daemon/pane.rs)。

## 已执行验证

```bash
cargo fmt --check
cargo +1.97.1 test --locked \
  locale_fallback_respects_inherited_and_configured_environments
```

结果：目标测试 1 项通过。

运行时调查还确认：当时 `/Applications/tty7.app` 的 GUI 与 daemon 进程只继承了 `HOME`，没有 `LC_ALL`、`LC_CTYPE` 或 `LANG`。当前 tmux client 后续已显示 `UTF-8` flag，但这不等同于上游 PR 已合入。

## 本机临时配置

当前本机配置保持：

```json
{
  "macos_option_as_alt": true,
  "env": {
    "LC_CTYPE": "UTF-8"
  }
}
```

`env` 片段是源码补丁合入前的持久 workaround。修改只影响 tty7 新创建的 shell；既有 shell/tmux client 不会追溯继承，需要从新 pane 重新 attach。

## 上游同步检查

### PR 合入

1. 记录上游 merge commit 和首次包含版本；
2. fast-forward 更新 fork `main`；
3. 将本特性状态改为 `absorbed`；
4. 下一版个人分支不再携带独立 locale 提交；
5. 使用纯上游代码新建 tty7 pane，验证 `locale charmap`、中文和 tmux；
6. 验证成功后可决定是否移除本机 `env.LC_CTYPE` workaround。移除不是自动步骤。

### PR 被拒绝或长期无进展

保持 `upstream-pr`，不要把它混入 `personal/meta-input` 的当前能力声明。若决定转为长期 fork 特性，应：

1. 从最新 `upstream/main` 建立新的个人版本分支；
2. 携带 locale 补丁及测试；
3. 状态改为 `active-fork`；
4. 使用 `scripts/install-local-macos.sh --full` 安装，因为修改位于 daemon shell spawn 路径；
5. 重新执行 tmux 端到端验证。

### 上游出现其他实现

若上游没有合并 PR #173，但引入了其他 locale 初始化逻辑，应比较以下语义：

- 是否只在 locale 全缺失时兜底；
- 是否尊重 Config 中显式空值；
- 是否仅限 macOS；
- 是否避免无条件覆盖 `LANG`/`LC_ALL`；
- 新 tmux client 是否获得 UTF-8 能力。

语义等价并通过验证后，同样可标为 `absorbed`。
