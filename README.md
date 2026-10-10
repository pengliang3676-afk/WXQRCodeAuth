# WXQRCodeAuth — 微信扫码授权中转（TrollStore）

一个极简的 iOS 中转 App：在**没有安装微信**的设备上，接管第三方 App（如百度系）的「微信登录 / 微信提现」跳转，把授权请求显示成二维码，用**另一台手机的微信**扫码确认后，授权码自动回跳给原 App，完成授权。

## 使用场景

- TrollStore 设备（iPhone/iPad）上不装微信，装百度系 App + 本工具
- 百度里点「微信登录 / 微信提现」时，系统找不到微信，会把 `weixin://` 授权请求交给本 App
- 点「显码」出现二维码 → 用另一台手机的微信扫码确认 → 自动跳回百度完成授权

## 工作原理

```
百度点微信授权
   │  weixin://  (设备无微信，系统改投本 App)
   ▼
WXQRCodeAuth 接管 URL，提取 appid / state / 来源 Bundle ID
   │  GET open.weixin.qq.com/connect/app/qrconnect  (UA 伪装微信)
   ▼
得到服务器 uuid，本地生成二维码（内容 .../connect/confirm?uuid=xxx）
   │  点「显码」展示
   ▼
另一台手机微信扫码确认
   │  长轮询 long.open.weixin.qq.com/connect/l/qrconnect
   ▼
wx_errcode=405，取 wx_redirecturl
   │  openURL:  wxAPPID://oauth?code=CODE&state=STATE
   ▼
跳回百度，授权完成
```

- **不需要**微信 AppID / AppSecret / 签名：appid 由第三方 App 跳转时带入，本工具只做中转
- **不需要**后端服务器：所有请求直接发给微信服务器
- **不需要**苹果开发者账号：产物为未签名 IPA，由 TrollStore 安装时自行签名

## 界面

只有：一个「显码」按钮、一个二维码区、一行状态文字。无登录、无后台、无其他功能。

## 自动编译（GitHub Actions）

推送到 `main` 分支即自动在 macOS runner 上编译：

1. XcodeGen 生成 Xcode 工程
2. `xcodebuild` 以 `CODE_SIGNING_ALLOWED=NO` 编译真机 arm64 包
3. 打包成 `WXQRCodeAuth-unsigned.ipa`
4. 在该次 Actions 运行的 **Artifacts** 中下载

## 本地编译（可选，需 macOS + Xcode）

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project WXQRCodeAuth.xcodeproj -scheme WXQRCodeAuth \
  -configuration Release -sdk iphoneos -arch arm64 \
  CODE_SIGNING_ALLOWED=NO clean build
# 产物在 build/Build/Products/Release-iphoneos/WXQRCodeAuth.app
mkdir Payload && cp -r build/Build/Products/Release-iphoneos/WXQRCodeAuth.app Payload/
zip -qr WXQRCodeAuth.ipa Payload
```

## 安装

用 TrollStore 打开 `WXQRCodeAuth-unsigned.ipa` 安装即可。支持 TrollStore 可覆盖的 iOS 版本（iOS 14 ~ 16.6.1 等，取决于设备）。

> 注意：设备上**不要安装微信**，否则第三方 App 会直接唤起真微信而不是本工具。

## 轮询状态码

| errcode | 含义 | 处理 |
|---|---|---|
| 408 | 长轮询超时 | 继续轮询 |
| 404 | 已扫码，待确认 | 提示手机端确认，继续轮询 |
| 405 | 授权成功 | 取 redirecturl 回跳来源 App |
| 403 | 用户取消 | 回跳来源 App（空 code） |
| 402 / 500 | 过期 / 错误 | 自动重新获取二维码 |

## IP 归属地查询（独立应用）

本仓库另含一款适配 iPhone SE 2 的 IP 查询 App，源码和使用说明位于 [`IP归属地查询/`](IP归属地查询/README.md)。它会自动查询当前公网 IP，并醒目显示中文归属地和运营商；对应的 **Build IP Lookup TrollStore IPA** 工作流生成独立 IPA，不影响上方 WXQRCodeAuth 的构建。
