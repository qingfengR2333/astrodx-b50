# AstroDX B50 悬浮窗（iOS dylib）

在 AstroDX 里常驻一个可拖动的「B50」悬浮球，点一下弹出面板，直接显示
总 Rating、旧曲 35 首、新曲 15 首的明细（定数 / 达成率 / 单曲 RA）。

读的是 **App 自己沙盒里的 `Documents/cache`**，不需要越狱路径权限，
也不需要知道你那个 `9A26521F-...` 的 UUID（注入进去之后 `NSHomeDirectory()`
就是 AstroDX 的容器，UUID 重装会变，所以代码里没有硬编码）。

## 结构

```
Tweak.x      悬浮球 + B50 面板（UIKit）
B50Core.h/.m 解压 cache(raw deflate) / 拉曲库 / 算 B50
Makefile     Theos 工程
control      deb 元信息（TrollFools 用不到，但留着）
.github/workflows/build.yml  GitHub Actions 一键出 dylib
```

## 怎么编译

这台 Windows 上没有 clang / theos / WSL，**编译不了**，二选一：

### A. 有 Mac
```bash
brew install ldid xz
git clone --recursive https://github.com/theos/theos.git ~/theos
export THEOS=~/theos
make
# 产物：.theos/obj/AstroDXB50.dylib
```

### B. 没有 Mac（推荐）
1. 把本文件夹传到一个 GitHub 仓库（私有就行）
2. 仓库的 **Actions** 页面 → `build-dylib` → Run workflow
3. 跑完在该次运行底部下载 `AstroDXB50` 压缩包，里面就是 `.dylib`

## 怎么装

1. 把 dylib 传到 iPad（AirDrop / 文件 App 都行）
2. 打开 **TrollFools** → 选 AstroDX → 注入 → 选中这个 dylib
3. 回到桌面重新打开 AstroDX，等 3 秒，右上角出现蓝色「B50」球
4. 点一下 → 弹出面板（iPad 上是浮动的 form sheet，可以拖）

## 已知限制（第一版）

* **首次读取需要联网**：曲库（约 1 MB，`maimai.lxns.net` 的公开接口）会下载到
  `Documents/astrodxb50_db.json`，之后 14 天内都走本地缓存，断网也能算。
* 面板是**文字列表**，没有复刻 PC 版那张图（把 GDI+ 的绘制搬到 UIKit 要重写一套，
  手机上其实列表更好读）。想要图的话可以再加一个「生成图片」按钮。
* 未签名 dylib 由 TrollFools 处理签名；iOS 16.3 + TrollStore 环境直接可用。
* 自制谱对不上官方曲库，会计入「未识别」，不参与 Rating —— 和 PC 版一致。

## 出问题时看什么

* 点了没反应：确认 TrollFools 注入的是 **AstroDX**，并且重启过 App
* 面板显示「读不到 cache」：说明 `Documents/cache` 不存在，先去游戏里打一首歌
* 显示「曲库数据格式不对」：接口那头改版了，把 `Documents/astrodxb50_db.json` 删掉重试
