# 文档入口

本目录同时包含上游 tty7 的公开功能说明和本 fork 的差异维护记录。

## 阅读路径

- 上游公开功能：[features.zh-CN.md](features.zh-CN.md)（[English](features.md)）
- 本 fork 相对上游的代码、工具和同步状态：[fork-features/README.md](fork-features/README.md)

## 权威边界

发生冲突时按以下顺序判断：

1. 当前分支的代码与测试；
2. `docs/fork-features/**` 对 fork 差异、验证状态和上游同步状态的记录；
3. 上游 `README*`、`docs/features*` 对未被 fork 修改部分的说明。

`docs/fork-features/**` 只记录相对上游的增量，不复制上游完整产品文档，也不把尚未合入当前分支的候选补丁描述为当前能力。
