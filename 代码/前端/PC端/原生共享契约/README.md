# PC 原生桌面 · 共享业务契约

![啄木鸟维修平台](../../../../icon.png)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、资产与维护入口](#assets)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本目录只包含两个原生工程共同使用的数据定义，不包含兼容层或界面源码。MacOS用SwiftUI、WindowsOS用WPF，分别构建、运行和验证。

## 一、<span id="assets">资产与维护入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件 | 语义与来源 |
| --- | --- |
| [actions.json](./actions.json) | 43项工单动作的字段、输入类型与默认值；`$owner`等由各端当前完整工单解析；与[后端合同](../../../后端/README.md#action-contract)同步 |
| [desktop-l10n.json](./desktop-l10n.json) | 十语原生文案；复用现有共享翻译并补充原生字段，业务输入原文不翻译 |
| [password-emoji-ranges.json](./password-emoji-ranges.json)／[Unicode-LICENSE.txt](./Unicode-LICENSE.txt) | 官方[Unicode 18 emoji-data](https://www.unicode.org/Public/18.0.0/ucd/emoji/emoji-data.txt)的排序合并数值区间：`Emoji_Presentation`80组／1228码点、`Emoji`150组／1447码点，©2026 Unicode, Inc.，按随包Unicode许可分发。两原生端共用；密码拒绝非ASCII Emoji（普通文本`©®™`保留）、VS16、keycap及含非ASCII Emoji的ZWJ／tag组合，普通文字、数字及标点保留；后端静态表按同一数据核对 |
| [Assets/LoanBorrow.svg](./Assets/LoanBorrow.svg)／[LoanReturn.svg](./Assets/LoanReturn.svg) | Jobs原创可编辑电路板借还凭据示意，PNG随两端打包；明确标注SYNTHETIC DEMO，分别演示借2／还1，不冒充真实客户原件。先查询iconfont，因图标不适合作为凭据而采用原创图形 |
| [demo.json](./demo.json) | 从现有Jobs自有iOS `WBDemoState`导出的各角色独立合成夹具；仅供Windows本地演示，不包含真实资料／会话／凭据 |
| [media-seed.json](./media-seed.json)／`Assets/Device*.png`／`Assets/DeviceInspection.mp4` | 三张原生桌面演示工单的设备参考附件；收件2图、确认／维修各1图1视频。元数据含字节数、SHA256、视频封面、作者与许可，不属于真实客户原件。运行时读取打包资源，点击查看／播放 |

设备参考素材先检查了 [iconfont电路板搜索](https://www.iconfont.cn/search/index?searchType=icon&q=%E7%94%B5%E8%B7%AF%E6%9D%BF)，图标不适合作设备照片与操作视频，改用可追溯的 [Wikimedia Commons](https://commons.wikimedia.org/) 素材。衍生文件继续使用各自相同的许可；不表示原作者认可本项目或这些演示工单。

| 随包文件 | 作者、来源与许可 | 处理 |
| --- | --- | --- |
| `DeviceIntake.png` | Cjp24，[Printed circuit board.jpg](https://commons.wikimedia.org/wiki/File:Printed_circuit_board.jpg)，[CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) | 等比缩至1280px并转换PNG，原图为万用表电路板，示例中仅作参考照片 |
| `DeviceBoard.png` | Alex P. Kok，[Fluke 79 Series II Multimeter circuit board 2.jpg](https://commons.wikimedia.org/wiki/File:Fluke_79_Series_II_Multimeter_circuit_board_2.jpg)，[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | 等比缩至1280px并转换PNG，保留实际电路板主体 |
| `DeviceRepair.png`／`DeviceInspection.mp4` | Glosome，[Circuit Soldering.gif](https://commons.wikimedia.org/wiki/File:Circuit_Soldering.gif)，[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | 原138帧焊接动画转H.264 MP4，13.8秒、480×360、无音轨；另取4秒处静帧作图片和视频封面 |

Mac构建直接引用同仓自有Foundation业务源码；Windows独立客户端实现同一HTTP合同。共享字段只描述表单，服务端权限、版本、金额及业务条件仍是提交边界。不得通过修改字段元数据绕开签署、付款或服务端拒绝。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
