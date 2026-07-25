# macOS Option/Meta 死键事件优先级

## 状态

- 生命周期：`active-fork-dependency`
- tty7 自用分支：`personal/meta-input`
- tty7 承载位置：`Cargo.toml` 的 Zed source patch
- Zed fork：`yoyooyooo/zed` 的 `tty7/macos-option-meta` 分支
- 行为提交：`81d1675 fix(gpui_macos): let apps handle Option chords before IME`
- 依赖兼容提交：`3389e1f build(gpui_macos): preserve upstream type identity when patched`
- 上游 PR：无；当前决定是 fork 内自用

## 问题

即使 tty7 已设置 `macos_option_as_alt=true`，`Option+N` 仍可能无法进入 tty7 的 `on_key_down`。原因不是 tty7 的 Meta 编码，而是 macOS 把 `Option+N` 视为 `~` 死键：GPUI 的 macOS 后端会先把可打印键或 `key_char` 为空的键交给 AppKit 输入上下文，TextInputUI 在应用回调前就可能消费该事件。

因此 tty7 上层的 `reshape_option_keystroke` 没有机会把它改写为 `Esc+n`，tmux 的 `M-n` 绑定也就收不到输入。`Option+E/U/I/\`` 等死键组合具有同一风险。

## 修复语义

fork 在 `gpui_macos::handle_key_event` 的两条“优先交给 IME”判断上排除 Alt/Option：

1. Alt/Option 事件先进入应用键盘回调；
2. tty7 开启 `macos_option_as_alt` 时，可将事件消费并重塑为 Meta；
3. 应用不消费时，GPUI 末尾原有的 `interpretKeyEvents` 回退仍会把原生事件交回 AppKit。

这不是 `Option+N` 特判，而是统一调整 Option 事件在“应用快捷键”和“IME/死键输入”之间的派发顺序。

## 依赖固化方式

`Cargo.toml` 保持 tty7、`gpui-component` 与 GPUI 主类型继续使用上游固定版本：

```text
zed-industries/zed@1d217ee39d381ac101b7cf49d3d22451ac1093fe
```

仅通过 source patch 替换 `gpui_macos`：

```toml
[patch."https://github.com/zed-industries/zed"]
gpui_macos = { git = "https://github.com/yoyooyooo/zed", rev = "3389e1f1a7a15c9a089475897888fafd6ac5e8a9" }
```

Zed fork 中的 `gpui_macos` 显式依赖原上游 SHA 的 `gpui`、`collections`、`media` 和 `util`，避免 Cargo 因仓库 URL 不同加载第二套 GPUI 类型。`Cargo.lock` 应只出现一个来自 `yoyooyooo/zed` 的包，即 `gpui_macos`。

不得再依赖手工修改 `~/.cargo/git/checkouts/**`；Cargo 缓存可以丢弃并重新获取，当前分支仍应构建出相同行为。

## 源码与配置锚点

- GPUI 行为：`yoyooyooo/zed` 的 `crates/gpui_macos/src/window.rs`，`handle_key_event`；
- GPUI source patch：tty7 根目录 `Cargo.toml`；
- 锁定结果：tty7 根目录 `Cargo.lock`；
- tty7 Option 重塑：`src/terminal/input.rs`，`reshape_option_keystroke`；
- tty7 Meta 交接：[未实现 Meta 键交给 PTY](meta-input-handoff.md)。

## 验证

自动验证：

```bash
cargo +1.97.1 build --release --locked
cargo tree --locked -i gpui_macos
```

依赖检查应显示 `gpui_macos` 来自 `yoyooyooo/zed@3389e1f`，而 `gpui` 仍来自 `zed-industries/zed@1d217ee`。

2026-07-25 已在安装后的 tty7 + tmux 中确认：

- `macos_option_as_alt=true` 时，`Option+N` 可触发 tmux `M-n` 并新建 window；
- 连按两次 `Option+X` 可触发既有 tmux 双击关闭绑定。

仍需补充的兼容性证据：关闭 `macos_option_as_alt` 后，`Option+N`、`Option+E` 等原生 macOS 死键组合是否完整保持。现有 GPUI 回退路径预期会保持该行为，但在完成手工验收前不得将其记为已证明。

## 上游同步检查

每次更新 Zed/GPUI 基线时：

1. 检查上游 `gpui_macos::handle_key_event` 的 IME 派发逻辑是否已有等价修复；
2. 若已吸收，在纯上游依赖上重跑真实 Option/Meta 与死键验收；
3. 验收通过后删除 source patch，并将本特性标记为 `absorbed`；
4. 若未吸收，将两个 fork 提交重放到新的 Zed 基线，重新确认显式内部依赖仍与 tty7 的 GPUI 类型同源；
5. 更新 `Cargo.lock`，确认没有意外引入第二套 `gpui`。
