# Plainleaf 0.1.0

本版本提供本地 Markdown 编辑、自动保存及外部修改冲突保护、分栏预览、目录、工作区搜索、脚注、阅读排版、HTML 导出及系统打印。正常退出前会保存待写入内容，保存失败或冲突未解决时取消退出；分栏滚动复用已有预览，减少重复渲染。

- 系统要求：macOS 15 或更新版本。
- Apple silicon 使用 `macos-arm64.zip`；Intel 使用 `macos-x86_64.zip`。
- 使用临时签名（ad-hoc），没有 Developer ID 签名或 Apple 公证。下载后可能被 Gatekeeper 拦截；确认来源和 SHA-256 后，按 macOS 的“系统设置 → 隐私与安全性 → 仍要打开”流程处理。不需要关闭系统安全保护。
- 解压后将 Plainleaf.app 拖入 Applications。升级前退出旧版本并保留旧 app，以便回退。普通 Markdown 文件始终是数据源。
- 附件包含每个架构的 SHA-256 校验文件、构建版本记录和本说明；第三方许可随 app 内的 `Contents/Resources/Licenses` 分发。

已知限制：分栏滚动按比例同步；单独修改磁盘图片后需重新打开预览；不加载远程图片，不执行 Markdown 内 HTML/JavaScript；未提供自动更新。临时签名安装流程参见 [Apple 官方说明](https://support.apple.com/en-us/102445)。完整人工验收记录见仓库 `docs/ACCEPTANCE_REPORT.md`，自动测试不能替代该记录。
