# <span id="前言">多语言国际化</span>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

## 一、使用说明 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

* 必要时，需要在启动时注册

  ```swift
  func application(_ application: UIApplication, didFinishLaunchingWithOptions
                   launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
      // MARK: - 语言跟随系统
      LanguageManager.shared.followSystemLanguage()
    
      // MARK: - 语言切换成固定的
      Bundle.enableLanguageOverride()
      /// 先切语言（会更新 localizedBundle）
      LanguageManager.shared.switchTo("vi")
      /// 再把 Bundle.main 指到你的语言 bundle（让 storyboard/xib 也变）
      Bundle.setLanguageBundle(LanguageManager.shared.localizedBundle)
    
      print("✅ currentLanguageCode =", LanguageManager.shared.currentLanguageCode)
      print("✅ preferredLanguages =", Locale.preferredLanguages)
      print("✅ bundlePath =", Bundle.main.path(forResource: LanguageManager.shared.currentLanguageCode, ofType: "lproj") ?? "nil")
  }
  ```
  
* 字符映射文件（默认）➤ `Localizable.strings`

* **应用层的调用方式**

  ```swift
  let to = (LanguageManager.shared.currentLanguageCode == "zh-Hans") ? "en" : "zh-Hans"
  LanguageManager.shared.switchTo(to)// zh-Hans、en
  ```

* 【基础】拿到当前语言字符串

  ```swift
  let s = "user.menu.fundDet".tr
  print(s)
  ```

* 【基础】短写本地化忽略大小写包含判断

  ```swift
  if "AppIcon".inStr(key) {
      print("hit")
  }
  ```

* 自动刷新**UI** ➤ 必须满足 2 个条件（否则不会自动在当前页面刷新**UI**）

  * **语言变化能触发刷新**（通知）且 **翻译来源 bundle 正确**（`TRLang.bundleProvider` 指向当前语言 bundle）
  * **UI 文案设置时走 TRBind/tr_setXXX 形成绑定注册**（而不是直接赋值/提前缓存翻译结果）

## 二、✅ UI 统一调用规范示例 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

调用方应引入 `JobsByUIKit`；按钮创建以及 UIKit 配置继续遵守 `JobsByUIKit` / `JobsSwiftDSL` 规范。

### 1、`UILabel` <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

* 普通文本

  ```swift
  titleLabel.tr_setText("KEY".tr)
  ```

* 富文本

  ```swift
  import JobsSwiftBaseDefines

  TRBind.bind(titleLabel, translated: "KEY".tr) { label, text in
      label.byAttributedText(
          NSAttributedString(
              string: text,
              attributes: [
                  .font: JobsFont.boldSystemFont(ofSize: 18),
                  .foregroundColor: JobsCor.systemBlue
              ]
          )
      )
  }
  ```

### 2、`UIButton` <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

* 普通文本

  ```swift
  UIButton.sys().tr_setTitle("KEY".tr, for: .normal)
  ```

* 富文本

  ```swift
  import JobsSwiftBaseDefines

  TRBind.bind(payButton, translated: "KEY".tr) { btn, text in
      btn.byAttributedTitle(
          NSAttributedString(
              string: text,
              attributes: [
                  .font: JobsFont.systemFont(ofSize: 16, weight: .medium),
                  .underlineStyle: NSUnderlineStyle.single.rawValue
              ]
          ),
          for: .normal
      )
  }
  ```

### 3、`UITextField` <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

* `placeholder`

  * 普通文本

    ```swift
    phoneField.tr_setPlaceholder("KEY".tr)
    ```

  * 富文本

    ```swift
    import JobsSwiftBaseDefines

    TRBind.bind(phoneField, translated: "KEY".tr) { tf, text in
        tf.byAttributedPlaceholder(
            NSAttributedString(
                string: text,
                attributes: [
                    .foregroundColor: JobsCor.gray,
                    .font: JobsFont.systemFont(ofSize: 14)
                ]
            )
        )
    }
    ```

* `text`

  * 普通文本

    ```swift
    phoneField.tr_setText("KEY".tr)
    ```

  * 富文本

    ```swift
    import JobsSwiftBaseDefines

    TRBind.bind(phoneField, translated: "KEY".tr) { tf, text in
        tf.byAttributedText(
            NSAttributedString(
                string: text,
                attributes: [
                    .foregroundColor: JobsCor.gray,
                    .font: JobsFont.systemFont(ofSize: 14)
                ]
            )
        )
    }
    ```

### 4、`UITextView` <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

> 原生的**UIKit**并不存在`UITextView.placeholder`

* 普通文本

  ```swift
  textView.tr_setText("KEY".tr)
  ```

* 富文本

  ```swift
  import JobsSwiftBaseDefines

  TRBind.bind(descView, translated: "KEY".tr) { tv, text in
      tv.byAttributedText(
          NSAttributedString(
              string: text,
              attributes: [
                  .font: JobsFont.systemFont(ofSize: 15),
                  .foregroundColor: JobsCor.secondaryLabel
              ]
          )
      )
  }
  ```

### 5、`UIBarButtonItem` <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

* ```swift
  navigationItem.tr_setTitle("KEY".tr)          /// 主标题（中间大字）
  navigationItem.tr_setPrompt("KEY".tr)         /// 主标题上方的一行小字
  navigationItem.tr_setBackButtonTitle("KEY".tr)/// 返回按钮文字
  ```

* ```swift
  navigationItem.rightBarButtonItem = UIBarButtonItem.make(title: nil)
  navigationItem.rightBarButtonItem?.tr_setTitle("KEY".tr)
  ```

### 6、`UITabBarItem` <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```swift
tabBarItem.tr_setTitle("KEY".tr)
```

### 7、`UISegmentedControl` <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```swift
segmentedControl.tr_setTitle("KEY".tr, forSegmentAt: 0)
segmentedControl.tr_setTitle("KEY".tr, forSegmentAt: 1)
```

### 8、`UISearchBar` <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```swift
searchBar.tr_setPlaceholder("KEY".tr)
searchBar.tr_setPrompt("KEY".tr)
```

### 9、`UIAlertController` <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```swift
let alert = UIAlertController.makeAlert()

alert
    .tr_setAlertTitle("KEY".tr)
    .tr_setMessage("KEY".tr)

alert.byAddAction(title: "KEY".tr)
present(alert, animated: true)
```

### 10、`UIView`（无障碍 `accessibilityLabel` / `Hint`） <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```swift
contentView
    .tr_setA11yLabel("KEY".tr)
    .tr_setA11yHint("KEY".tr)
```

### 11、`UIViewController`.`title` <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```swift
TRBind.bind(self, translated: "KEY".tr) { vc, text in
    vc.byTitle(text)
}
```




















<a id="jobs-architecture"></a>

## 三、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 3.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

将语言选择、语言码归一化、Bundle 查词和已绑定 UI 自动刷新连接起来。LanguageManager 管理当前语言，Bundle 扩展改变本地化查找目标，TRAutoRefresh 与 UIKit 入口登记需要随语言变化重放的赋值。

### 3.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

设置或恢复语言 → 选择对应 lproj → 翻译键查词 → 登记 UI 文本绑定 → 语言切换通知触发刷新

### 3.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 只替换一次文字不会自动获得持续刷新，必须理解 tr_setText 等绑定入口与翻译键登记之间的关系。
- 语言码到资源目录存在归一化规则，简繁中文和地区变体不能只截取前两个字符。
- 普通文本、富文本与输入占位有不同赋值路径，UITextView 本身没有原生 placeholder 属性。
- Bundle.main 的覆盖具有全局影响，业务应统一管理语言入口，避免多个库各自安装互相冲突的覆盖。

### 3.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先读 LanguageManager、TRLang，再看 Bundle/String 扩展，最后追 TRAutoRefresh 与 UIKit 的登记、通知和释放。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [Jobsl10n.swift](<./Jobsl10n.swift>)
- [LanguageManager.swift](<./LanguageManager.swift>)
- [TRAutoRefresh.swift](<./TRAutoRefresh.swift>)
- [TRLang.swift](<./TRLang.swift>)
- [Foundation&UIKit/Bundle+多语言国际化.swift](<./Foundation&UIKit/Bundle+多语言国际化.swift>)

依赖与编译入口：[Jobsl10n.podspec](<./Jobsl10n.podspec>)。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

## 四、使用合同与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 语言状态、provider 和绑定表的内部读写受锁保护，语言变化通知与控件 apply 在主线程执行。注入 provider 的求值及旧 provider / 绑定捕获对象的释放在锁外，支持读取状态与析构重入；provider 自身捕获的可变状态由调用方隔离。
- `followSystemLanguage()` 同时恢复系统模式并清除 Bundle 覆盖；完整语言码找不到资源时再查基础语言码，最终回退原资源 Bundle。把 `Bundle.main` 设为覆盖 Bundle 会自动清除覆盖，避免自调用递归。
- 每个目标以 `slot` 区分独立属性，重复绑定同一 slot 替换旧 key；注册表弱持有目标并清理失效项。UIKit 入口已为文本、placeholder、按钮 state 和分段索引分别设置 slot。
- 推荐 `TRBind.bind(target, key: "KEY", table: nil, slot: "title") { target, text in ... }` 显式绑定。旧 `translated:` API 和默认 `"default"` slot 继续兼容，线程 marker 只接受匹配的翻译值；普通字符串、nil 与富文本替换会解除对应旧 slot。
- 同一对象自定义多个属性绑定时必须传不同 slot；直接给 UIKit 属性赋值不会自动解除注册，应使用本库设置入口或 `TRAutoRefresh.unbind(target, slot:)`。
- apply 闭包应使用传入 target，不再强捕获目标本身。后台 bind 的初次 UI 写入异步投递主队列；依赖完成顺序的界面配置在主线程串行调用。


## 五、生产交付与全量门禁 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

生产源码排除 Tests / Test、Demo / Example、build / DerivedData、测试入口及临时文件；回归脚本位于宿主 `.github/tests/JobsPodsUpgrade`，不被 Pod 生产 target 编入。

隐私清单通过独立资源 bundle 交付。当前所需理由 API：`UserDefaults`（CA92.1）。理由对应本库实际用途；宿主仍需核对业务数据收集、App Group / 用户授权文件等实际使用场景，资源声明与最终 App 内 bundle 都应验收。

从宿主根目录执行当前 Pod 单元验证：

```shell
ruby .github/tests/JobsPodsUpgrade/validate_builds.rb --pods Jobsl10n --skip-host
```

全量命令为 `ruby .github/tests/JobsPodsUpgrade/validate_builds.rb`：逐个自建 Pod 编译成功后才构建宿主 workspace。当前集成验证使用最低部署目标 iOS 15.6 / arm64 Simulator / Swift 5 语言模式；独立 Pod 更低部署目标、动态集成和真机行为需相应消费配置验证。编译日志、JSON 结果及行为回归边界见宿主根目录《JobsByPods升级与编译验收报告.md》，不能用 Parse 或 fixture 的成功替代真实模块 / App 编译。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
