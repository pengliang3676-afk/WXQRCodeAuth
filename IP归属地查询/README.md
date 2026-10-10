# IP 归属地查询

适配 iPhone SE 2 的轻量 iOS IP 查询应用。打开后自动查询当前公网 IP，并醒目显示中文归属地和运营商；可查看 ASN、时区和坐标。

## 基础项目与许可

本项目基于 [What IP](https://github.com/JesusChapman/What-ip) 的开源 iOS 项目进行改造，采用其 GPL-3.0 许可，并保留原项目应用图标。改造依据的上游提交为 `a95f81ad55697d94f786b196fc122e1fcc4be88a`。上游要求 iOS 26；本项目改为 iOS 15 起可运行，加入中文界面，并使用中文归属地和常见运营商名称。

IP 数据由 [ipwho.is](https://ipwho.is/) 提供。应用会将当前公网 IP 发送给该服务；归属地使用简体中文，常见运营商名称会转换为中文。结果仅为 IP 网络位置估算，不能代表设备的精确位置。

## 构建 TrollStore IPA

GitHub Actions 工作流会在 `codex/ip-lookup` 分支有新提交时自动构建未签名 IPA。工作流进入默认分支后，也可手动运行 **Build IP Lookup TrollStore IPA**：

1. 打开 GitHub 仓库的 **Actions**。
2. 选择 **Build IP Lookup TrollStore IPA**。
3. 在该次运行的 Artifacts 下载 `IP归属地查询-TrollStore-IPA`。
4. 将 IPA 传到 iPhone，在 TrollStore 中安装。

IPA 由 Xcode 为真机 arm64 编译，关闭 Apple 代码签名，供 TrollStore 安装。TrollStore 本身仍需与设备 iOS 版本兼容。

也可以在 macOS 上运行：

```sh
xcodebuild -project "IP归属地查询.xcodeproj" -scheme IPLookup \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

完整许可见 [LICENSE](LICENSE)。
