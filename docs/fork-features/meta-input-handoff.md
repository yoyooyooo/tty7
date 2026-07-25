# 未实现 Meta 键交给 PTY

## 状态

- 生命周期：`active-fork`
- 自用分支：`personal/meta-input`
- 引入提交：`1457c48 fix(input): hand off unhandled Meta chords`
- 上游提交：无
- 上游 PR：无；当前决定是 fork 内自用
- 端到端状态：已在本机 APP + tmux 中确认 `Option+N` 与双击 `Option+X`
- 下层依赖：[macOS Option/Meta 死键事件优先级](macos-option-meta-ime.md)

## 问题

macOS 设置 `macos_option_as_alt=true` 后，tty7 会把 `Option+字母` 重塑为 Meta 键。但 shell prompt 上的本地行编辑器只实现 `M-b`、`M-f`、`M-d`，其他 Alt/Meta 字母原本会成为静默 no-op。

这会阻断外层 tmux 的无 prefix 绑定。例如本机 tmux 已正确加载：

```tmux
bind -n M-n new-window
bind -n M-x run-shell -b ".../kill_pane_double_tap.sh ..."
```

在 fork 修改前，tty7 本地编辑器先吞掉 `M-n` / `M-x`，tmux 收不到任何输入。

## 设计约束

不能简单把未知 Meta 字节直接写入 PTY。tty7 在 prompt 上维护自己的命令缓冲区，而 shell 的 zle/readline 缓冲区此时可能为空；直接透传会让两份缓冲区分叉。

fork 复用现有 `handoff_line_to_shell`：

1. 将 tty7 当前单行草稿发送给 shell；
2. 将光标同步到等价位置；
3. 清空本地编辑器并把本轮 prompt 的输入所有权交给 shell；
4. 再发送 Meta 键，让 tmux、zle 或 readline 处理。

## 当前行为

- `M-b`、`M-f`、`M-d` 继续由 tty7 本地编辑器处理；
- 其他可打印、单字符 Meta 键尝试编码并 handoff 到 PTY；
- `Option+N` 因而可到达 tmux 的 `M-n`；
- 第一次 `Option+X` handoff 后，本轮 prompt 已由 shell/PTY 接管，第二次 `Option+X` 走原始输入路径，可完成双击确认；
- named keys（方向键、Enter 等）仍沿用原有分支，不属于这次修改。

## 源码与测试锚点

- 行为入口：`src/terminal/view.rs`，`TerminalView::handle_editor_key` 中 Meta chord 分支；
- 缓冲区交接：`src/terminal/view.rs`，`TerminalView::handoff_line_to_shell`；
- 输入重塑：`src/terminal/input.rs`，`reshape_option_keystroke`；
- 回归测试：`src/terminal/view.rs`，`meta_chords_edit_locally_or_handoff_to_the_pty`；
- 原有开关测试：`src/terminal/input.rs`，`option_as_alt_on_sends_esc_plus_base_key`。

## 已执行验证

```bash
cargo fmt --check
cargo +1.97.1 test --locked meta_chords_edit_locally_or_handoff_to_the_pty
cargo +1.97.1 test --locked option_as_alt
```

结果：Meta handoff 测试 1 项通过；Option-as-Meta 原有测试 2 项通过。

安装验证：`scripts/install-local-macos.sh --gui-only` 已成功构建 Release、替换 `/Applications/tty7.app`、重新 ad-hoc 签名并启动；daemon PID 保持不变。

真实按键验证（2026-07-25）：`Option+N` 可新建 tmux window；连续两次 `Option+X` 可触发双击关闭绑定。`Option+N` 还依赖 GPUI 层避免死键事件在 tty7 回调前被 AppKit 消费，详见下层依赖文档。

## 已知限制

1. `M-b/M-f/M-d` 仍由本地编辑器优先处理；若 tmux 也绑定这些键，tmux 仍收不到它们。
2. `handoff_line_to_shell` 不接受包含换行的草稿，因此多行草稿下未知 Meta 键仍可能被吞掉。
3. handoff 后，当前 prompt 剩余输入由 shell 管理；tty7 的本地补全、历史和 ghost suggestion 要到下一轮 prompt 才重新接管。
4. 单元测试只验证编码和 handoff 顺序；真实 Option 事件仍需依赖 GPUI source patch 和端到端验收。
5. 关闭 `macos_option_as_alt` 后的原生 macOS 死键兼容性尚未完成手工验收。

## 手工验收

在安装后的 tty7、tmux prompt 中验证：

```text
Option+N       新建 tmux window
Option+X 两次  关闭当前 pane；最后一个 pane 被关闭时 window 随之关闭
```

同时确认：

- 单次 `Option+X` 不误关闭；
- `Option+B/F/D` 原有本地编辑行为未回归；
- 普通字符和中文输入未受影响；
- 输入一段单行草稿后触发 `Option+N`，返回旧 pane 时草稿仍由 shell 正确持有。

## 上游同步检查

每次更新上游后搜索：

```bash
rg -n "Other Alt|Meta chord|handoff_line_to_shell|reshape_option_keystroke" \
  src/terminal/view.rs src/terminal/input.rs
```

若上游开始把未实现 Meta 键安全交给 PTY：

1. 在纯上游分支运行本页测试和手工验收；
2. 确认上游同样处理本地缓冲区交接，而不是直接写字节造成双缓冲区分叉；
3. 通过后将本特性标为 `absorbed`，记录上游提交，下一版个人分支不再携带 `1457c48` 中对应代码；
4. 若上游只覆盖部分按键，缩小 fork 差异并更新限制列表。
