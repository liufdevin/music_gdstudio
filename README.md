# LF Music

一个使用 Flutter 编写的音乐搜索、播放和下载示例项目。

## 功能

- 搜索歌曲、歌手或专辑
- 选择音乐源和音质
- 播放、暂停、拖动进度
- 显示歌曲封面和歌词
- Android 前台媒体播放通知，退出应用后可继续播放
- 单首歌曲下载
- 多选歌曲批量下载

## 数据来源

本项目的音乐搜索、播放地址、封面和歌词数据来源于：

[GD音乐台(music.gdstudio.xyz)](https://music.gdstudio.xyz)

本项目仅用于 Flutter 学习和技术演示，请遵守相关音乐平台、接口服务和当地法律法规要求。

## 环境要求

- Flutter SDK
- Dart SDK
- Android Studio 或可用的 Android 构建环境

当前项目使用的主要依赖：

- `http`
- `audio_service`
- `just_audio`
- `audio_session`
- `file_selector`
- `cross_file`

## 运行

获取依赖：

```bash
flutter pub get
```

运行到 Android 设备：

```bash
flutter run
```

构建 Android Debug APK：

```bash
flutter build apk --debug
```

## Android 说明

项目已配置播放所需权限和服务：

- 网络访问
- 前台服务
- 媒体播放前台服务
- 唤醒锁
- 通知权限

在 Android 13 及以上系统，如果下拉通知栏没有显示播放通知，请检查系统设置中本应用的通知权限是否开启。

## 验证

```bash
flutter analyze
flutter test
flutter build apk --debug
```
