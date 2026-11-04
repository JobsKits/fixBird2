# <span id="前言">[**Swift**](https://developer.apple.com/swift/).<font size=8 color=blue>**`UIKit`**</font>@拓展工具</span>

![Jobs倾情奉献](https://picsum.photos/1500/400 "Jobs出品，必属精品")

## 编者按 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

* 做成[**Cocoapods**](https://cocoapods.org/)比较困难，对于作者来讲，难以维护。经过多番科学评估以后，故决定对此库放弃**Pods**化

  * 因为[**Cocoapods**](https://cocoapods.org/)的品控要求，所以在正式发布**Pods**组件之前需要自检，当且只有自检成功方可成功发布
  * **Pods**组件之间不允许循环引用
  * 而目前这个库，因为是对于系统框架<font size=5 color=blue>**`UIKit`**</font>的深度拓展封装，就不可避免的对一些基础的库有循环引用的场景。如果要打破这个场景，就必须对代码结构产生修改。而作者的意图是此拓展工具是关于<font size=5 color=blue>**`UIKit`**</font>的相关类的分类，进行完全统一的管理

* 目前已经**Pods**化的一些基础工具集

  ```ruby
  pod 'JobsSwiftBaseTools'                 # https://github.com/JobsKits/JobsSwiftBaseTools
  pod 'JobsSwiftBaseDefines'               # https://github.com/JobsKits/JobsSwiftBaseDefines
  pod 'JobsSwiftFoundation@Extensions'     # https://github.com/JobsKits/Jobs.Swift.Foundation.Extensions
  pod 'JobsSwiftMetalKit@Extensions'       # https://github.com/JobsKits/Jobs.Swift.MetalKit.Extensions
  ```

  

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
