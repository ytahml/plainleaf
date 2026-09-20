# 构建、临时签名与发布

## 本地验证和打包

要求 macOS 15+、Xcode 26.1.1 / Swift 6.2.1、Python 3、系统 zsh。CI 明确选择 Xcode 26.1.1，锁定依赖于 `Package.resolved`；不需要证书、Apple 账号或签名 secrets。

```sh
swift test --force-resolved-versions
./scripts/build-app.sh
./scripts/package-release.sh
```

`build-app.sh` 默认构建本机架构，也接受 `ARCH=arm64` 或 `ARCH=x86_64`。先在全新目录组装资源和原始许可证，以 `codesign --sign -` 签名，再检查签名、entitlements、Mach-O 架构、macOS 15.0 部署目标、字体和高亮资源。成功后才替换 `build/Plainleaf.app`；旧 app 移至 `build/previous.*`，失败现场也保留。不要并发运行构建或打包脚本。

`package-release.sh` 会重新构建，在独立 `build/release.*` 目录生成 ZIP、构建来源记录、版本说明及 SHA-256 文件，再解压验证签名与内容。输出最后一行为产物目录。目录内 `extracted/` 供本地验收，不作为发布附件。构建记录会注明工作树改动；正式发布必须使用干净提交。

```sh
cd build/release.实际目录
shasum -a 256 -c Plainleaf-0.1.0-macos-arm64-SHA256SUMS.txt
```

## CI 与发布门槛

PR、main 推送和手工运行均在 macOS 15 的 ARM/Intel runner 上执行完整测试、Release 构建、临时签名、ZIP 往返验证并上传保留 14 天的构建附件。普通 CI 仅有读取仓库权限。配置依据 [GitHub runner 镜像](https://github.com/actions/runner-images)；托管镜像可能更新，Xcode 路径失效时应明确更新并重新验证。

1. 修改 `Sources/Plainleaf/Resources/Info.plist` 的 `CFBundleShortVersionString`（三段数字）和递增的 `CFBundleVersion`，同步 `docs/RELEASE_NOTES.md`。
2. 完成测试和 `docs/ACCEPTANCE.md` 的人工检查，更新验收记录；在 macOS 15.7 上验证解压后的 app。对 Intel 的声明需要 Intel 实机证据。
3. 提交并推送审定版本后，为该提交创建并推送匹配版本的 `vX.Y.Z` tag。tag 推送是发布流程的显式入口；不要移动已发布 tag。
4. 两个架构全部通过后，独立的最小 `contents: write` job 创建 **GitHub Release 草稿**，附 ZIP、校验和、构建记录及说明。tag 与 plist 不一致会立即失败。
5. 下载草稿附件、核对校验和、签名与人工验收记录后，在 GitHub 手动发布草稿。流水线不会自动公开二进制。

已有同名 Release 时创建会失败，不覆盖旧附件。修复未发布版本时先检查现有草稿和失败日志；对已公开版本使用新版本和新 tag。回退时退出应用，换回保留的旧 app；不修改工作区文件。

临时签名只提供本地代码完整性，不提供发行者身份或公证信任。安装与 Gatekeeper 边界见 [版本说明](RELEASE_NOTES.md)。未来需要 Developer ID / 公证时另行配置，当前不引入证书管理或自动更新服务。
