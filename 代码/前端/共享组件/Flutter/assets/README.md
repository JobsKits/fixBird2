# <span id="前言">本地素材</span>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

- `RepairLogo.png`：复用本仓库 `代码/前端/PC端/Web/维修工作台/assets/RepairLogo.png`，各端启动图标由该图等比缩放生成，不引入网络图片。
- `NotoSansSC.ttf`：Google Fonts 官方 [Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc)，2026-10-30 获取；SIL Open Font License 1.1，全文见同目录 `NotoSansSC-OFL.txt`。字体随包加载，中文显示不依赖字体 CDN。
- Material 控件与字体来自 Flutter SDK；页面未引入第三方图标或远程装饰图。
- `NotoSerifTibetan.ttf`：复用已校验的 [Google Fonts 官方固定版本](https://github.com/google/fonts/blob/8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5/ofl/notoseriftibetan/NotoSerifTibetan%5Bwght%5D.ttf)，补齐藏文字形，SHA-256 为 `060ec022b04c306de3f58d051fb0e1cf81a5b610c5910fbfc43bba154c057cda`；完整许可随包保留在 `NotoSerifTibetan-OFL.txt`。
- `NotoSansCJKsc-Regular.otf`：复用 [Noto CJK 官方固定版本](https://github.com/notofonts/noto-cjk/blob/f8d157532fbfaeda587e826d4cd5b21a49186f7c/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf)，补齐繁中、日文和韩文字形，SHA-256 为 `2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b`；完整许可为 `NotoSansCJK-OFL.txt`。两份字体二进制均未修改，作为同一语义字体体系的字形回退，运行时不依赖字体 CDN。
- `ui-l10n.json` 是共享界面语言资源的打包副本，维护源为 `../../Resources/ui-l10n.json`。界面语言只翻译呈现文案，不改请求、字段标识、用户输入和业务原始记录。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
