# SafeBaiyun - iOS

广州市白云区蓝牙门禁的离线 iOS 版本。

只需要门禁的 MAC 地址以及加密 Key 即可开门，无需网络。支持添加多个门禁设备。

## 安装

### 方式一：Xcode 构建（自签/证书签）

1. 打开 Xcode，创建新的 iOS App 项目
2. 项目名称：SafeBaiyun，界面：SwiftUI，支持最低 iOS 14.0
3. 将 `SafeBaiyun/` 目录下的所有 Swift 文件添加到项目中
4. 将 `Info.plist` 替换或合并到项目配置中
5. 配置签名（个人 Apple ID 或开发者证书）
6. 选择你的设备，Build & Run

### 方式二：巨魔 / TrollStore

1. 用 Xcode 构建出 `.ipa` 文件
2. 通过 TrollStore 安装即可

### 方式三：在线签名服务

将构建出的 `.ipa` 上传到各类在线签名平台即可。

## 使用说明

1. 点击右上角 ⚙️ 进入设备管理
2. 点击 + 添加设备，填写名称、MAC 地址、加密 Key
3. 返回主页面，点击对应设备的「开门」按钮
4. 确保门禁设备在蓝牙范围内

## 技术说明

- 最低支持 iOS 14.0
- 使用 CoreBluetooth 连接门禁
- 数据保存在本地 UserDefaults
- 通信协议与 Android 版完全兼容（Service UUID: `14839AC4-7D7E-415C-9A42-167340CF2339`）
- 加密算法：DES/ECB/NoPadding

## 提取 MAC 地址及加密密钥

请参考同仓库的 `extract.md` 文件。