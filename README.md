# lut-shop

lut-shop 是一个移动端优先的摄影 LUT/预设管理与照片批量处理工具。当前版本重点覆盖 iOS：导入照片、图库筛选与选择集、单张预览调色、LUT 管理、批量同步调整、导出到系统照片，以及 Sony 相机 FTP 自动导入的基础链路。

## 当前能力

- iOS SwiftUI App，暗色摄影工作台风格。
- 从系统照片或文件导入图片，图库索引会持久化。
- 图库支持会话、搜索、筛选、排序、评分、收藏、选择集和批量删除。
- 预览页支持 LUT 应用、强度调节、前后对比、保存、撤销。
- 详情页可把当前照片已保存的 LUT/强度同步到其他已选照片。
- LUT 库支持系统分类、自定义分类、添加、重命名、删除、收藏和详情分类切换。
- 导出页只按每张照片已保存的调整导出，不在导出阶段选择 LUT。
- 导出结果会写入系统“照片”。
- C++ core 已接入 iOS Objective-C++ 桥，当前用于 LUT 加载与像素预览链路。
- Sony FTP 接收界面和本机 FTP receiver 基础实现已接入，用于相机主动上传照片。

## macOS 快速开始

前置条件：

- macOS
- Xcode 已安装，并至少安装一个 iOS Simulator runtime
- Xcode Command Line Tools 可用

运行：

```bash
./mac.sh
```

脚本会执行：

1. 构建 `apps/ios/LutShop.xcodeproj` 的 `LutShop` scheme。
2. 自动选择一个已启动或可用的 iPhone 模拟器。
3. 覆盖安装 App。
4. 启动 `com.lutshop.app`。

只构建不启动：

```bash
./mac.sh --build-only
```

指定模拟器型号：

```bash
LUT_SHOP_DEVICE="iPhone 17 Pro" ./mac.sh
```

脚本不会卸载 App，也不会清空模拟器数据，所以已经导入的图库索引会保留。

## Android 快速开始

前置条件：

- Android Studio 或 Android SDK 可用
- JDK 17
- 如需自动安装启动，先连接 Android 设备或启动模拟器，并确保 `adb` 可用

运行：

```bash
./android.sh
```

脚本会通过 `apps/android/gradlew` 构建 debug APK。检测到 Android 设备或模拟器时，会自动安装并启动 `com.lutshop`；没有设备时只完成构建。

## 手动构建

```bash
xcodebuild \
  -project apps/ios/LutShop.xcodeproj \
  -scheme LutShop \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData \
  build
```

## 项目结构

```text
apps/ios/              iOS SwiftUI App
apps/android/          Android 方向说明与原型骨架
core/                  跨端 C++ core
assets/                设计和素材入口
docs/                  产品、架构、计划和审计记录
mac.sh                 macOS 快速构建/安装/启动脚本
android.sh             Android 快速构建/安装/启动脚本
```

## iOS 关键目录

```text
apps/ios/LutShop/AppState.swift                 App 状态、图库、导入、导出、选择集、相机接收编排
apps/ios/LutShop/Models.swift                   Swift 数据模型
apps/ios/LutShop/Core/LutShopCppBridge.mm       Swift/Objective-C++/C++ 桥接
apps/ios/LutShop/Core/CameraReceiveService.swift FTP 接收服务
apps/ios/LutShop/Views/                         Gallery / Preview / LUT / Export / Camera UI
apps/ios/LutShop/Resources/BundledLuts/         内置 .cube LUT
apps/ios/LutShop/Resources/Localizable.xcstrings 中英文翻译
```

## 当前产品交互说明

### 图库选择集

图库里的“选择”会进入选择模式。点“完成”只退出选择模式，不清空选择集；已选照片在普通浏览状态下会保留白色边框。再次进入选择模式时会显示当前选择数量。清空选择仍使用已有的“清空”按钮。

### 调色与同步

单张照片在预览页选择 LUT、调整强度后，需要点“保存”。如果图库里已有其他已选照片，可以在详情页点“同步到已选”，把当前照片已保存的 LUT 和强度同步给其他已选照片，当前照片本身不会重复处理。

### 导出

导出不再选择 LUT。导出页只读取每张照片自己的已保存状态：

- 有已保存 LUT：导出处理后效果。
- 无已保存 LUT：导出原图。

导出格式、尺寸、质量和 EXIF 仍在导出页设置。

## C++ core

`core/` 存放跨端核心类型和工作流，iOS 通过 Objective-C++ 桥调用。下一步适合继续把更多业务规则从 Swift 下沉到 C++ core，例如：

- LUT catalog 和 user LUT 管理
- Session/photo index
- 批量导出任务模型
- Android JNI facade

## Android

Android 方向文档在 [apps/android/README.md](apps/android/README.md)。当前已有 Kotlin + Compose 原型骨架和 Gradle Wrapper，可以通过 `./android.sh` 先跑通 debug build。后续建议通过 NDK/JNI 接入同一个 C++ core。
