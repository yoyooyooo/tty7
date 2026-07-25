# macOS 本地热替换工具

## 状态

- 生命周期：`active-fork-tooling`
- 自用分支：`personal/meta-input`
- 引入提交：`1457c48 fix(input): hand off unhandled Meta chords`
- 工具入口：`scripts/install-local-macos.sh`
- 上游化计划：无；该脚本服务个人 fork 的本机安装循环

## 目的

Rust 代码修改不需要每次重新生成 DMG。tty7 的 GUI 与 daemon 共用同一个可执行文件：

```text
/Applications/tty7.app/Contents/MacOS/tty7
```

脚本完成以下闭环：

1. 按当前机器架构执行 Release 构建；
2. 关闭 tty7 GUI；
3. 按模式决定是否停止 daemon；
4. 备份已安装二进制；
5. 替换 APP 内二进制；
6. 对 APP 重新执行 ad-hoc 签名并验证；
7. 重新启动 APP。

## 使用方式

仅修改 GUI/终端视图代码时：

```bash
scripts/install-local-macos.sh --gui-only
```

该模式保留现有 daemon、PTY、shell 和 tmux 会话。适用于 `src/ui/**`、`src/terminal/**` 中不改变 daemon 协议的修改。

修改 daemon、PTY、shell 环境或协议时：

```bash
scripts/install-local-macos.sh --full
```

该模式调用已安装二进制的 `--stop-daemon`，会结束 tty7 管理的所有 shell。只有明确接受会话终止时才能使用。

环境覆盖：

```text
TTY7_APP_PATH    默认 /Applications/tty7.app
RUST_TOOLCHAIN   默认 1.97.1
TTY7_BACKUP_DIR  默认 ~/Library/Application Support/tty7-local-build-backups
```

当前分支通过 `Cargo.toml` 和 `Cargo.lock` 固化 [macOS Option/Meta 死键事件优先级](macos-option-meta-ime.md) 补丁。安装脚本无需、也不应再手工修改 `~/.cargo/git/checkouts/**`；全新 Cargo 缓存应能从锁定的 fork 提交重建。

## 当前实现边界

这是“替换 Rust 可执行文件”的快速路径，不同步以下 bundle 资源：

- `Info.plist`；
- 图标；
- `assets/completions`；
- entitlements；
- Bundle ID；
- DMG 和公证产物。

这些内容发生变化时，应改用上游脚本：

```bash
cargo +1.97.1 build --release --locked --target aarch64-apple-darwin
bash .github/scripts/bundle-macos.sh aarch64-apple-darwin arm64
```

上游 bundle 脚本会重建 `dist/`，运行前不得在其中保存其他资料。

## 签名与并存限制

热替换会破坏原 Developer ID 签名，因此脚本重新施加 ad-hoc 签名。它适合本机自用，不应把该 APP 作为面向其他机器的可信分发物。

fork APP 仍沿用：

```text
Bundle ID: com.github.tty7
配置目录: ~/.config/tty7
```

因此 fork APP 与上游 APP 不适合并行运行。当前策略是 fork 二进制替换 `/Applications/tty7.app`，上游原二进制保存在备份目录。

## 已执行验证

2026-07-25 使用以下命令完成首次安装：

```bash
scripts/install-local-macos.sh --gui-only
```

验证结果：

- Release 构建成功；
- 已安装 Mach-O UUID 与 Release 构建 UUID 一致；
- APP 的 ad-hoc 签名通过 `codesign --verify --deep --strict`；
- GUI 成功重新启动；
- daemon PID 保持 `24494`，证明 GUI-only 安装未重启既有 daemon；
- 安装前二进制备份到：

```text
~/Library/Application Support/tty7-local-build-backups/20260725-184854/tty7
```

PID 和备份时间戳只是该次证据，不是长期不变量。

## 回滚

先退出 GUI，再将所需备份复制回 APP，重新签名并启动：

```bash
cp "$HOME/Library/Application Support/tty7-local-build-backups/<timestamp>/tty7" \
  /Applications/tty7.app/Contents/MacOS/tty7
chmod 755 /Applications/tty7.app/Contents/MacOS/tty7
codesign --force --deep --sign - /Applications/tty7.app
codesign --verify --deep --strict --verbose=2 /Applications/tty7.app
open /Applications/tty7.app
```

若回滚涉及 daemon 代码或协议，应在复制前使用 `--stop-daemon`，并接受现有 shell 被结束。

## 上游同步检查

每次更新上游后检查：

1. `.github/scripts/bundle-macos.sh` 是否改变 APP 结构、签名要求或二进制路径；
2. Cargo/Rust 最低版本是否改变；
3. GUI 与 daemon 是否仍由同一二进制承担；
4. `--stop-daemon` 和 `--config-dir` 语义是否改变；
5. `src/terminal/**` 修改是否仍可安全使用 `--gui-only`。

只要其中任一假设失效，先更新脚本和本页，再运行下一次热替换。
