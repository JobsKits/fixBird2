//
//  JobsBaseEnumDefs.swift
//  JobsSwiftBaseDefines
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - 输入模式
public enum JobsTextInputMode: Int {
    case space      /// 点按：空格按键
    case delete     /// 点按：删除按键
    case `return`   /// 点按：回车按键
    case normal     /// 普通的点按
}
// MARK: - 启动检查的枚举
public enum LaunchKind {
    case firstInstallLaunch /// 安装后第一次
    case firstLaunchToday   /// 今天第一次
    case normal             /// 普通启动
}
// MARK: - 开发环境
public enum JobsNetworkingEnvir: NSInteger {
    case undefined = 0,
         dev,    /// 开发环境
         test,   /// 测试环境
         uat,    /// UAT环境
         product /// 生产环境
}
// MARK: - 文件类型枚举定义
public enum FileType: UInt {
    case txt = 0,/// 文本文件
         image,  /// 图片文件
         video,  /// 视频文件
         sound,  /// 音频文件
         plist   /// 属性列表文件
}
// MARK: - 图片填充模式
public enum DWContentMode: Int {
    case scaleAspectFit,  /// 适应模式
         scaleAspectFill, /// 填充模式
         scaleToFill      /// 拉伸模式
}
// MARK: - 启动模式
public enum BitsMonitorRunMode: UInt {
    case autoRun = 0,/// 自启动模式
         manualRun   /// 手动启动模式
}
// MARK: - 启动状态
public enum DispatchTimerState: Int {
    case `init` = 0,
         resume,
         suspend
}
// MARK: - 屏幕分辨率
public enum iPhScrPxType: UInt {
    case none
    case _4_4S,                             /// 屏幕分辨率(px) = 640 * 960
         _5_5C_5S_SE,                       /// 屏幕分辨率(px) = 640 * 1136
         _6_6S_7_8_SE2,                     /// 屏幕分辨率(px) = 750 * 1334
         _6_6S_7_8Plus                      /// 屏幕分辨率(px) = 1242 * 2208
    /// 从这里开始刘海屏
    case X_XS_11Pro,                        /// 屏幕分辨率(px) = 1125 * 2436
         Xr_11,                             /// 屏幕分辨率(px) = 828 * 1792
         XSMax_11ProMax                     /// 屏幕分辨率(px) = 1242 * 2688
    /// iPhone 12 系列
    case _12mini,                           /// 屏幕分辨率(px) = 1080 * 2340
         _12_12Pro,                         /// 屏幕分辨率(px) = 1170 * 2532
         _12ProMax                          /// 屏幕分辨率(px) = 1284 * 2778
    /// iPhone 13 系列
    case _13mini,                           /// 屏幕分辨率(px) = 1080 * 2340
         _13_13Pro,                         /// 屏幕分辨率(px) = 1170 * 2532
         _13ProMax                          /// 屏幕分辨率(px) = 1284 * 2778
    /// iPhone 14 系列
    case _14,                               /// 屏幕分辨率(px) = 1170 * 2532
         _14Plus,                           /// 屏幕分辨率(px) = 1284 * 2778
         _14Pro,                            /// 屏幕分辨率(px) = 1179 * 2556
         _14ProMax                          /// 屏幕分辨率(px) = 1290 * 2796
    /// iPhone 15 系列
    case _15,                               /// 屏幕分辨率(px) = 1170 * 2532
         _15Plus,                           /// 屏幕分辨率(px) = 1284 * 2778
         _15Pro,                            /// 屏幕分辨率(px) = 1179 * 2556
         _15ProMax                          /// 屏幕分辨率(px) = 1290 * 2796
    /// iPhone 16 系列
    case _16,                               /// 屏幕分辨率(px) = 1170 * 2532
         _16Plus,                           /// 屏幕分辨率(px) = 1284 * 2778
         _16Pro,                            /// 屏幕分辨率(px) = 1179 * 2556
         _16ProMax                          /// 屏幕分辨率(px) = 1290 * 2796
}
// MARK: - 平台维护状态
public enum JobsAppStatus: Int {
    case undefined = 0,
         maintenance,   /// 平台维护中
         ok,            /// 平台正常
         close          /// 平台关闭
}
// MARK: - 终端类型
public enum JobsOperationType: Int {
    case undefined = 0,  /// 未定义
         pc,             /// PC端
         iosNative,      /// 原生iOS
         iosWebView,     /// iOS内嵌WebView网页
         iosBrowser      /// iOS浏览器网页
    case androidNative,  /// 原生Android
         androidWebView, /// Android内嵌WebView网页
         androidBrowser, /// Android浏览器网页
         unknown         /// 未知
}
// MARK: - 控制器的推进方式
public enum ComingStyle: UInt {
    case unknown = 0, push, present, pop
}
// MARK: -
public enum JobsHeaderFooterViewStyle: Int {
    case none = 0, header, footer
}
// MARK: - WGradientProgress
public enum WGradientProgressType: UInt {
    case colorNormal = 0,/// 单一色
         colorRoll       /// 色彩在不断的翻滚
}
// MARK: - 倒计时模式
public enum TimerStyle: UInt {
    case clockwise = 0,/// 顺时针模式
         anticlockwise /// 逆时针模式（倒计时模式）
}
// MARK: - 排序方向
public enum SortingType: Int {
    case positive = 0,/// 排序方向-正序
         reverse      /// 排序方向-倒序
}
// MARK: - 用哪一种模式进行初始化NSTimer定时器
public enum ScheduledTimerType: UInt {
    case type0 = 0,/// scheduledTimerWithTimeInterval/repeats/block
         type1,    /// scheduledTimerWithTimeInterval/invocation/repeats
         type2     /// scheduledTimerWithTimeInterval/target/selector/userInfo/repeats
}
// MARK: - NSTimer定时器当前状态
public enum NSTimerCurrentStatus: UInt {
    case unknown = 0,/// 定时器未知状态
         run,        /// 定时器正在运行
         stop,       /// 定时器停止
         pause,      /// 定时器暂停
         destroy     /// 定时器销毁
}
// MARK: - 登录方式
public enum JobsLoginType: Int {
    case silent = 0,/// 静默登录（只在账密登录成功后有效）
         manual     /// 非静默登录
}
// MARK: - 更新类型
public enum JobsUpdateType: Int {
    case undefined,/// 不更新
         bySys,    /// 系统强制更新
         byUser,   /// 用户手动更新
         all       /// 系统自动更新
}
// MARK: - 系统支持语言
public enum AppLanguage: Int {
    case bySys,      /// App语言跟随当前系统
         Simplified, /// zh-Hans：简体中文
         Traditional,/// zh-Hant：繁体中文
         English,    /// en：标准英语
         Tagalog     /// tl：菲律宾他加禄语
}
// MARK: -
public enum IntervalStyle: UInt {
    case seconds = 0,/// 单位：秒
         milliseconds/// 单位：毫秒
}
// MARK: - 屏幕方向
public enum DeviceOrientation: Int {
    case unknown, /// 未知方向
         portrait,/// 竖屏
         landscape/// 横屏
}
// MARK: - 文字方向
public enum TransformLayerDirectionType: UInt {
    case up = 0,/// 文字方向朝上(默认正常)
         left,  /// 文字方向朝左
         down,  /// 文字方向朝下
         right  /// 文字方向朝右
}
// MARK: -
public enum NSObject_SPAlertControllerInitType: UInt {
    case type1 = 0,/// alertControllerWithTitle/message/preferredStyle
         type2,    /// alertControllerWithTitle/message/preferredStyle/animationType
         type3,    /// alertControllerWithCustomAlertView/preferredStyle/animationType
         type4,    /// alertControllerWithCustomHeaderView/preferredStyle/animationType
         type5     /// alertControllerWithCustomActionSequenceView/title/message/preferredStyle/animationType
}
// MARK: - 计时器运行状态
public enum TimerProcessType: Int {
    case ready = 0,/// 准备状态
         running,  /// 运行状态
         pause,    /// 暂停运行状态
         resume,   /// 恢复运行状态
         stop      /// 结束状态
}
// MARK: - Label 的表现方式
public enum UILabelShowingType: UInt {
    case type01 = 1,/// 一行显示。定宽、定高、定字体。多余部分用…表示（省略号的位置由NSLineBreakMode控制）
         type02,    /// 一行显示。定宽、定高、定字体。多余部分scrollerView
         type03,    /// 一行显示。不定宽、定高、定字体。宽度自适应 【单行：ByFont】
         type04,    /// 一行显示。定宽、定高。缩小字体方式全展示 【单行：ByWidth】
         type05     /// 多行显示。定宽、不定高、定字体 【多行：ByFont】
}
// MARK: - 当前类型
public enum ComponentType: Int {
    case unknown,      /// 其他
         view,         /// 视图
         viewController/// 控制器
}
// MARK: - 时区
public enum TimeZoneType: Int {
    case UTC,               /// 协调世界时
         GMT,               /// 格林尼治标准时间
         PST,               /// 太平洋标准时间 (美国和加拿大)
         EST,               /// 东部标准时间 (美国和加拿大)
         CST,               /// 中部标准时间 (美国和加拿大)
         MST,               /// 山地标准时间 (美国和加拿大)
         CSTChina,          /// 中国标准时间
         JST,               /// 日本标准时间
         BST,               /// 英国夏令时
         AEST,              /// 澳大利亚东部标准时间
         AWST,              /// 澳大利亚西部标准时间
         CET,               /// 欧洲中部时间
         MSK,               /// 莫斯科标准时间
         IST                /// 印度标准时间
    case BRT,               /// 巴西利亚时间
         CSTMexico,         /// 墨西哥城时间
         ART,               /// 阿根廷时间
         HST,               /// 夏威夷标准时间
         AKST,              /// 阿拉斯加标准时间
         CEST,              /// 中欧夏令时
         EET,               /// 欧洲东部时间
         WET,               /// 欧洲西部时间
         NST,               /// 纽芬兰标准时间
         AST,               /// 大西洋标准时间
         PDT,               /// 太平洋夏令时
         MDT,               /// 山地夏令时
         CDT,               /// 中部夏令时
         EDT,               /// 东部夏令时
         NZST,              /// 新西兰标准时间
         HKT,               /// 香港时间
         SGT,               /// 新加坡时间
         MYT,               /// 马来西亚时间
         KST                /// 韩国标准时间
}
// MARK: - 图片编码格式
public enum PicToStrStyle: Int {
    case hexadecimal = 0,/// 图片 转 十六进制
         base16,         /// 图片 转 Base16字符编码
         base32,         /// 图片 转 Base32字符编码
         base64,         /// 图片 转 Base64字符编码
         base85,         /// 图片 转 Base85字符编码
         mime            /// 图片 转 MIME
}
// MARK: - 刷新阶段
public enum RefreshingType: Int {
    case beginRefreshing = 0,/// 开始刷新
         endRefreshing       /// 结束刷新
}
// MARK: - banner滚动方向
public enum JhtBannerViewOrientation: Int {
    case horizontal,/// 横向
         vertical   /// 纵向
}
// MARK: - JobsDropDownListView的方向
public enum JobsDropDownListViewDirection: Int {
    case down = 0,
         up
}
/**
 后台定义：
 
 【返回状态码(code)】
 -1、服务器异常。
 0、表示成功。
 1、登录已过期，请重新登录。
 2、授权失败。
 4、限定时间内超过请求次数
 6.、风险操作。
 7、未设置交易密码。
 8、帐号已在其他设备登录。
 
 【需要权限的接口】请求头加上authorization字段，值为服务器颁发的jwt令牌。令牌无感刷新，需实时更新
 */
// MARK: - 请求数据返回的状态码、根据自己的服务端数据来
public enum HTTPResponseCode: Int {
    case serveError = 10005               /// 服务器异常
    case success = 200                    /// 请求成功
    case noToken = 401                    /// 令牌不能为空
    case loginFailed = 1002000000         /// 登录失败：账密错误
    case authorizationFailure = 2         /// 授权失败
    case leakTime = 4                     /// 限定时间内超过请求次数
    case riskOperation = 6                /// 风险操作
    case noSettingTransactionPassword = 7 /// 未设置交易密码
    case offline = 8                      /// 帐号已在其他设备登录
    case tokenExpire = 10009              /// Token 过期
    case phoneNumberNotExist = 1002000034 /// 手机号码不存在
    case noOK = 500                       /// 服务器错误
    case accountLocked = 1002000035       /// 账户被锁
    case withdrawMaintenance = 1006000014 /// 提现功能维护
    ///其他代号，展示msg内容即可
}
// MARK: - 语言
public enum HTTPRequestHeaderLanguageType: Int {
    case en,  /// 英文
         cn,  /// 中文
         other/// 其他语言
}
// MARK: - 抖音模式
public enum MKRightBtnViewBtnType: Int {
    case love,   /// 点赞
         comment,/// 评论
         share   /// 分享
}
// MARK: - 方向
public enum JobsResolvedEdge {
   case top,
        bottom,
        left,
        right
}

public enum JobsDirection: UInt {
    case top,   /// 上面
         bottom,/// 下面
         left,  /// 左边
         right  /// 右边
    public var isHorizontal: Bool {
        switch self {
        /// 合并处理 .top、.bottom 分支
        case .top, .bottom: return false
        /// 合并处理 .left、.right 分支
        case .left, .right: return true
        }
    }
    /// 是否垂直方向（与 isHorizontal 语义对称）
    public var isVertical: Bool {
        switch self {
        /// 合并处理 .top、.bottom 分支
        case .top, .bottom: return true
        /// 合并处理 .left、.right 分支
        case .left, .right: return false
        }
    }
}

public extension JobsDirection {
    @available(iOS 13.0, *)
    var toDirectionalEdge: NSDirectionalRectEdge {
        switch self {
        /// 处理 .top 分支
        case .top:    return .top
        /// 处理 .left 分支
        case .left:   return .leading
        /// 处理 .bottom 分支
        case .bottom: return .bottom
        /// 处理 .right 分支
        case .right:  return .trailing
        }
    }
    /// 在不使用 NSDirectionalRectEdge 的前提下，给你同样的 leading/trailing 语义：
    /// - 当系统是 RTL 时：left/right 互换
    /// - top/bottom 不变
    func resolved(for layout: UIUserInterfaceLayoutDirection) -> JobsResolvedEdge {
        switch self {
        /// 处理 .top 分支
        case .top: return .top
        /// 处理 .bottom 分支
        case .bottom: return .bottom
        /// 处理 .left 分支
        case .left:
            return layout == .rightToLeft ? .right : .left
        /// 处理 .right 分支
        case .right:
            return layout == .rightToLeft ? .left : .right
        }
    }
}
// MARK: - 前进方向@一维
public enum JobsValueMode {
    /// 0 → 1 显示为 0% → 100%
    case countUp
    /// 0 → 1 显示为 100% → 0%
    case countDown
}
// MARK: - 前进方向@二维
public enum JobsAxisDirection {
    case leftToRight
    case rightToLeft
    case topToBottom
    case bottomToTop
}

public enum JobsPushDirection: Int {
    case system = 0
    case fromLeft
    case fromRight
    case fromTop
    case fromBottom
}
// MARK: - 前进方向@三维
public enum JobsGradientDirection {
    /// ← →
    case leftToRight
    /// → ←
    case rightToLeft
    /// ↑ ↓
    case topToBottom
    /// ↓ ↑
    case bottomToTop
    /// ↖︎ ↘︎
    case topLeftToBottomRight
    /// ↘︎ ↖︎
    case bottomRightToTopLeft
    /// ↗︎ ↙︎
    case topRightToBottomLeft
    /// ↙︎ ↗︎
    case bottomLeftToTopRight
    /// 自定义（0~1）
    case custom(start: CGPoint, end: CGPoint)
}

public extension JobsGradientDirection {
    var points: (start: CGPoint, end: CGPoint) {
        switch self {
        /// 处理 .leftToRight 分支
        case .leftToRight:
            return (.init(x: 0, y: 0.5), .init(x: 1, y: 0.5))
        /// 处理 .rightToLeft 分支
        case .rightToLeft:
            return (.init(x: 1, y: 0.5), .init(x: 0, y: 0.5))
        /// 处理 .topToBottom 分支
        case .topToBottom:
            return (.init(x: 0.5, y: 0), .init(x: 0.5, y: 1))
        /// 处理 .bottomToTop 分支
        case .bottomToTop:
            return (.init(x: 0.5, y: 1), .init(x: 0.5, y: 0))
        /// 处理 .topLeftToBottomRight 分支
        case .topLeftToBottomRight:
            return (.init(x: 0, y: 0), .init(x: 1, y: 1))
        /// 处理 .bottomRightToTopLeft 分支
        case .bottomRightToTopLeft:
            return (.init(x: 1, y: 1), .init(x: 0, y: 0))
        /// 处理 .topRightToBottomLeft 分支
        case .topRightToBottomLeft:
            return (.init(x: 1, y: 0), .init(x: 0, y: 1))
        /// 处理 .bottomLeftToTopRight 分支
        case .bottomLeftToTopRight:
            return (.init(x: 0, y: 1), .init(x: 1, y: 0))
        /// 处理 .custom 分支
        case let .custom(start, end):
            return (start, end)
        }
    }
}
// MARK: - 滚动方向
public enum ScrollDirection: Int {
    case none = 0,
         right,     /// 右👉🏻
         left,      /// 左👈🏻
         up,        /// 上面👆🏻
         down       /// 下面👇🏻
    case rightUp,   /// 右上👉🏻👆🏻
         leftUp,    /// 左上👈🏻👆🏻
         rightDown, /// 右下👉🏻👇🏻
         leftDown   /// 左下👈🏻👇🏻
}
// MARK: - 比较结果
public enum CompareRes: Int {
    case error,
         moreThan,  /// >
         equal,     /// ==
         lessThan   /// <
}
// MARK: - 搜索策略
public enum JobsSearchStrategy: Int {
    case accurate = 0,/// 精确查询
         fuzzy        /// 模糊查询
}
// MARK: - 订单相关@时间定义
public enum JobsOrderDate: Int {
    case undefined = -1,
         today,     /// 今天
         yesterday, /// 昨天
         in7Days,   /// 近7天内
         inOneMonth,/// 一个月内
         all        /// 全部
}
// MARK: - 订单相关@支付类型
public enum JobsPayType: Int {
    case undefined,       /// 未定义
         bankCard,        /// 银行卡
         alipay,          /// 支付宝
         wechat,          /// 微信支付
         crypto,          /// 数字货币
         manual,          /// 人工后台操作上下分
         appBalance,      /// App余额支付
         mataValue,       /// Mata值支付
         mataCreditScore, /// 信用分支付
         all
}
// MARK: - 订单相关@默认支付类型
public enum JobsPayDefaultType: Int {
    case undefined,
         main,      /// 主支付类型
         other,     /// 副支付类型
         all
}
// MARK: - 订单相关@订单类型
public enum JobsOrderType: Int {
    case undefined,
         mall,       /// 商城订单
         creditScore,/// 信用分订单
         course,     /// 课程订单
         all
}
// MARK: - 订单相关@存取款
public enum BankStyle: Int {
    case deposit,/// 存款
         withdraw/// 提款
}
// MARK: - 订单相关@订单状态
public enum JobsOrderState: Int {
    case undefined
    case due,               /// 待付款订单
         waitSent,          /// 已付款.待发货订单
         waitReceived,      /// 已发货.待收货订单
         evaluate,          /// 已完成收货的订单，并且待评价
         finished           /// 已完成收货的订单，并且已经评价
    case pendingReview,     /// 待审核订单
         reviewed,          /// 已审核订单
         payoutError,       /// 订单出款错误
         deleted,           /// 订单已经被删除
         all
}
// MARK: - 会员相关@更新用户信息类型
public enum JobsUpdateUserInfoType: Int {
    case undefined = 0,     /// 未定义
         nation,            /// 国家
         nationality,       /// 民族
         realName,          /// 真实姓名
         nickName           /// 花名
    case age,               /// 年龄
         birthday,          /// 生日
         sex,               /// 性别
         sexualOrientation, /// 性倾向
         mail               /// 邮箱地址
    case wechat,            /// 微信账号
         qq,                /// QQ账号
         telephone,         /// 手机号码
         sinaWeibo,         /// 新浪微博账号
         telegram           /// 纸飞机账号
    case instagram,         /// Instagram账号
         facebook,          /// Facebook账号
         skype,             /// Skype账号
         whatsApp,          /// WhatsApp账号
         all                /// 全部更新
}
// MARK: - 会员相关@会员等级
public enum JobsRankClass: Int {
    case undefined = 0, vip0, vip1, vip2, vip3, vip4, vip5, vip6, vip7, vip8, vip9, vip10, all
}
// MARK: - 会员相关@活动状态
public enum JobsActiveState: Int {
    case undefined = 0,/// 未定义
         joined,       /// 参与活动
         levelMismatch,/// 等级不符
         joining,      /// 正在参与活动
         joinedBefore, /// 已参与过活动
         all
}
// MARK: - 会员相关@开关状态
public enum JobsSwitchType: Int {
    case open = 0,/// 启用（正常）
         close    /// 停用
}
// MARK: - 会员相关@开关状态
public enum JobsSwitchType2: Int {
    case close = 0,/// 停用
         open      /// 启用（正常）
}
// MARK: - 会员相关@客服平台标识
public enum JobsCustomerContactStyle: Int {
    case undefined = 0,/// 未定义
         qq,           /// QQ
         skype,        /// Skype
         telegram,     /// Telegram
         whatsApp,     /// WhatsApp
         phoneNumber,  /// 手机号码
         onlineURL,    /// onlineURL
         all
}
// MARK: - 会员相关@消息类型
public enum JobsMsgType: Int {
    case undefined = 0,/// 未定义
         notify,       /// 通知
         activity,     /// 活动
         notice,       /// 公告
         bonus,        /// 红利
         all
}
// MARK: - 会员相关@账户类型
public enum AccountStyle: Int {
    case gcCash,/// GCCash
         bank   /// 银行
}
// MARK: - 会员相关@
public enum FMActionType: Int {
    case signin = 0,     /// 注册
         login,          /// 登录
         forgotPwd,      /// 忘记密码
         bindMobile,     /// 绑定手机号
         bindBankCard,   /// 绑定银行卡
         bindEwallet,    /// 绑定加密货币地址
         withdraw        /// 提现
}
// MARK: - 会员相关@
public enum FMGameListStyle: Int {
    case new = 0,/// 最新
         hot,    /// 热门
         all,    /// 全部
         fav     /// 最爱
}
// MARK: - 会员相关@KYC
public enum VerificationStatus: Int {
    case unverified = 0,/// 未认证
         verifying,     /// 认证中
         verified       /// 已认证
}
// MARK: - 会员相关@广告类型
public enum FMAdsType: Int {
    case homeBanner = 0     /// 首页天顶轮播大Banner
    case navbarMini = 1     /// 导航栏4小Banner
    case hotRecommend = 2   /// APP首页右下3Banner
    case memberCentral = 3  /// APP会员中心
    case promotionArea = 4  /// 活动推广专区
    case announcement = 5   /// 公告
    case homeWindowPop = 6  /// 首页弹窗广告
}
// MARK: - 会员相关@账号类型
public enum FMAccType: Int {
    case allMember = 0,     /// 所有会员
         designatedMember,  /// 指定会员
         allAgency,         /// 全代理线
         designatedAgency   /// 指定代理线
}
// MARK: - 会员相关@跳转类型
public enum FMJumpType: Int {
    case designatedGame = 0,/// 指定游戏
         stadium,           /// 场馆大厅
         activity,          /// 活动模块
         webURL,            /// 网站地址
         noJump             /// 不跳转
}
// MARK: - 会员相关@跳转类型：记录是什么触发登录操作的（登录成功继续进行流程）
public enum FMLoginWork: Int {
    case `default` = 0, myFav, myBank
}
// MARK: - 会员相关@KYC状态
public enum KYCStatus: Int {
    case pending = 0,/// 待审核
         approved,   /// 通过
         rejected,   /// 拒绝
         notSubmitted/// 未提交
}
// MARK: - 会员相关@提现额度
public enum JobsWithdrawalAmountType: Int {
    case normal = 0,/// 普通提现
         largeAmount/// 大额提现
}
// MARK: - 会员相关@是否已KYC验证
public enum KYCOK: Int {
    case failed = 0,/// 未通过
         passed     /// 已经通过
}
// MARK: - 会员相关@首页游戏列表名
public enum HomeBarListStyle: Int {
    case sports = 1001101,      /// Sports 体育
         liveCasino = 1001102,  /// Live Casino 真人
         tableGames = 1001103,  /// Table Games 棋牌
         slotsGames = 1001104,  /// Slots Games 电子
         lottery = 1001105,     /// Lottery 彩票
         esport = 1001106       /// ESport 电竞
}
// MARK: - 会员相关@绑定状态
public enum BindStyle: Int {
    case unbound = 0,/// 未绑定
         bound = 1   /// 已绑定
}
// MARK: - 会员相关@绑定状态
public enum NeedRealName: Int {
    case noNeed = 0,/// 不需要
         need1,     /// 需要-单姓名
         needMore   /// 需要-可以多姓名
}
// MARK: - 会员相关@ID 类型
public enum IdTypeEnum: Int {
    case philNationalID = 1,        /// Philippine National ID
         driversLicense = 2,        /// Driver's License
         philHealthID = 3,          /// PhilHealth ID
         postalID = 4,              /// Philippine Postal ID
         nbiClearance = 5           /// NBI Clearanc
    case seniorCard = 6,            /// Senior Citizen Card
         passport = 7,              /// ID Passport (Philippine/Foreign)
         ibpID = 8,                 /// Integrated Bar of the Philippines ID
         firearmsLicense = 9,       /// Firearms License
         prc = 10,                  /// Professional Regulations Commission
         ofwID = 11                 /// Overseas Filipino Workers (OFW) ID
    case sssCard = 12,              /// Social Security System (SSS) Card
         tin = 13,                  /// Tax Identification
         umid = 14,                 /// Unified Multi-Purpose ID
         votersID = 15,             /// Voter's Certificate and/or Voter's ID
         marinaID = 16,             /// Maritime Industry Authority (MARINA) ID
         pwdID = 17,                /// Person's with Disability (PWD) iD
         acr = 18,                  /// Alien Certificate of Registration
         icr = 19                   /// Immigrant Certificate of Registration
}
// MARK: - 会员相关@活动类型：1、日常； 2、签到 ；3、存款优惠
public enum ActivityType: Int {
    case normal = 0,        /// 日常
         signin = 1,        /// 签到
         depositPromo = 2   /// 存款优惠
}
// MARK: - 会员相关@奖励发放：1、自动发放；2、人工审核
public enum RewardDistributionType: Int {
    case auto = 1,  /// 自动发放
         manual = 2 /// 人工审核
}
// MARK: - 会员相关@活动周期：1、长期有效；2、指定时间
public enum ActivityDuration: Int {
    case longterm = 1,      /// 长期有效
         specifiedTime = 2  /// 指定时间
}
// MARK: - 会员相关@活动分类：0、新手；1、日常；2、优惠；3、限时
public enum ActivityCategory: Int {
    case newbie = 0,    /// 新手
         daily = 1,     /// 日常
         promotion = 2, /// 优惠
         limitedTime = 3/// 限时
}
// MARK: - 会员相关@活动状态：-2、删除；-1、过期；0、禁用；1、预热；2、开启
public enum ActivityStatus: Int {
    case deleted = -2,  /// 删除
         expired = -1,  /// 过期
         disabled = 0,  /// 禁用
         preheating = 1,/// 预热
         Open = 2       /// 开启
}
// MARK: - 会员相关@代理线设置：1、全部参与；2、排除代理线；3、指定代理线
public enum AgentLineSetting: Int {
    case all = 1, /// 全部参与
         exclude, /// 排除代理线
         specified/// 指定代理线
}
// MARK: - 会员相关@是否有子游戏：1.有 0.没有
public enum HasSubSetting: Int {
    case no = 0,/// 没有子游戏
         yes = 1/// 有子游戏
}
// MARK: - 会员相关@是否热门：0.是 1.否
public enum IsHotGameSetting: Int {
    case hot = 0,  /// 是热门游戏
         notHot = 1/// 不是热门游戏
}
// MARK: - 会员相关@状态：0.开始 1.禁用
public enum StatusSetting: Int {
    case started = 0,/// 开始
         disabled = 1/// 禁用
}
// MARK: - 会员相关@电子标签类型：1. Hot 2. New
public enum ElectronicLabelTypeSetting: Int {
    case hot = 1,/// 热门
         new = 2 /// 新品
}
// MARK: - 会员相关@用户类型设置
public enum UserTypeSetting: Int {
    case register = 1,      /// 注册
         login = 2,         /// 登录
         forgetPwd = 3,     /// 忘记密码
         bindPhone = 4,     /// 绑定手机号
         bindBankCard = 5,  /// 绑定银行卡
         bindCrypto = 6,    /// 绑定加密货币地址
         payPwdSet = 7,     /// 支付密码设置
         payPwdReset = 8,   /// 支付密码修改
         withdrawalReq = 9, /// 代理提款申请
         deposit = 10,      /// 代理代存
         bindEWallet = 11   /// 绑定电子钱包
}
// MARK: - 会员相关@业务来源
public enum BusinessSourceSetting: Int {
    case member = 1,/// 会员（默认）
         agent = 2  /// 代理
}
// MARK: - 会员相关@站内信类型
public enum FMINBOXTYPE: Int {
    case undefined = -1,    /// 未定义或所有类型
    sportsAnnouncement = 1, /// 体育赛事公告
    promo,                  /// 推广
    news,                   /// 新闻
    personal,               /// 个人
    announcement            /// 公告
}
// MARK: - 会员相关@当前类型
public enum ReadStatus: Int {
    case unread,/// 未读
         read   /// 已读
}
// MARK: - 会员相关@结算状态
public enum SettleFlag: Int {
    case no = 0,/// 未结算
         yes    /// 已结算
}
// MARK: - 会员相关@查询时间类型
public enum JobsQueryTimeType: Int {
    case specific = 0,  /// 具体时间
         today,         /// 当天
         yesterday,     /// 昨天
         within7Days,   /// 7天内
         within30Days   /// 30天内
}
// MARK: - 会员相关@交易订单统一状态
public enum JobsTransactionStatus: Int {
    case all = -1,   /// 查询全部
    processing = 0,  /// 处理中
    success,         /// 成功
    failure,         /// 失败
    review           /// 审核中
}
// MARK: - 会员相关@交易订单类型
public enum JobsTransactionType: Int {
    case all = -1,   /// 查询全部
    deposit = 1,     /// 充值（存款）
    withdraw,        /// 提现
    transfer,        /// 转账
    rebate = 5,      /// 返水
    bonus,           /// 红利
    systemAdjustment,/// 系统调整
    live             /// 直播
}
// MARK: - 会员相关@交易类型
public enum JobsTransactionDirection: Int {
    case income = 0,/// 收入
         expense    /// 支出
}
// MARK: - 会员相关@线上支付渠道
public enum FMWalletType: Int {
    case gcash = 1, /// GCash
         mayaPay,   /// MayaPay
         grabPay    /// GrabPay
}
// MARK: - 会员相关@提现类型
public enum FMWithdrawalType: Int {
    case bankCard = 0,/// 银行卡提现
         exclusive,   /// 专属提现
         usdt,        /// USDT 提现
         ebpay,       /// EBpay 提现
         ewallet      /// 电子钱包提现
}
// MARK: - 会员相关@广告标签类型
public enum FMAdTagType: Int {
    case all = 0,    /// 全部广告
         limitedTime,/// 限时广告
         newAccount, /// 新账户广告
         daily       /// 日常广告
}
// MARK: - 会员相关@教程标签类型
public enum FMTutorialType: Int {
    case common = 1,/// 常见教程
         aboutUs = 2/// 关于我们
}
// MARK: - 会员相关@来源类型枚举定义
public enum SourceType: UInt {
    case home = 0,/// 来自首页
         favorite /// 来自收藏
}
// MARK: - 会员相关@数据来源
public enum DataSourceType: UInt {
    case unknown = 0,   /// 未知来源
         login,         /// 登录
         register,      /// 登录
         forgotPassword,/// 忘记密码
         settingNewPwd  /// 修改密码
}
// MARK: - 会员相关@资金渠道
public enum JobsFundsChannel: Int {
    case allBank = 0,
         fortunePay,
         gcash,
         instarPay,
         lazada,
         maya,
         pisopay,
         qrph,
         unionBank
}
// MARK: - 网络鉴权
public enum JXAuthCode: UInt {
    case tokenEmpty        = 10006  // 令牌为空
    case tokenInvalid      = 10007  // 令牌错误
    case loginExpired      = 10008  // 登陆过期
    case authorizationFail = 10014  // 授权失败
    case success           = 10000  // 成功
}
// MARK: - 中国公民身份证校验
public enum CNIDError: Error, CustomStringConvertible {
    case format, birthDate, sequence, checksum
    public var description: String {
        switch self {
        /// 处理 .format 分支
        case .format:    return "格式错误：18位(前17位数字+最后一位数字或X) 或 15位纯数字"
        /// 处理 .birthDate 分支
        case .birthDate: return "出生日期无效或超出合理范围"
        /// 处理 .sequence 分支
        case .sequence:  return "顺序码无效（不能为000）"
        /// 处理 .checksum 分支
        case .checksum:  return "校验位不匹配"
        }
    }
}
// MARK: - 颜色的定义
public enum JobsCorConst {
    static let main_color: UIColor      = UIColor(named: "MainColor")!
    // MARK: - 文本 626C90、A6B0C8
    static let text0_color: UIColor      = UIColor(named: "TextColor0")!
    static let text1_color: UIColor      = UIColor(named: "TextColor1")!
    static let text2_color: UIColor      = UIColor(named: "TextColor2")!
    static let text3_color: UIColor      = UIColor(named: "TextColor3")!
    // MARK: -通用文本色
    static let public_text_4: UIColor      = UIColor(named: "public-text-4")!
    static let public_text_5: UIColor      = UIColor(named: "public-text-5")!
    static let public_text_6: UIColor      = UIColor(named: "public-text-6")!
    static let public_text_7: UIColor      = UIColor(named: "public-text-7")!
    // MARK: -通用提示色
    static let public_FZ_1: UIColor      = UIColor(named: "public-FZ-1")!
    static let public_FZ_2: UIColor      = UIColor(named: "public-FZ-2")!
    static let public_FZ_3: UIColor      = UIColor(named: "public-FZ-3")!
    // MARK: -通用蒙版色
    static let public_MASK: UIColor      = UIColor(named: "public-MASK")!
    // MARK: -分割线
    /// light: E2E2E2 dark:373A40
    static let line0: UIColor      = UIColor(named: "Line0")!
    // MARK: -背景
    static let view_bg_color1: UIColor      = UIColor(named: "ViewColor1")!
    static let view_bg_color2: UIColor      = UIColor(named: "ViewColor2")!
    static let view_bg_color3: UIColor      = UIColor(named: "ViewColor3")!
    static let view_bg_color4: UIColor      = UIColor(named: "ViewColor4")!
    static let view_bg_color5: UIColor      = UIColor(named: "ViewColor5")!
    static let view_bg_color6: UIColor      = UIColor(named: "ViewColor6")!
    static let view_bg_color9: UIColor      = UIColor(named: "ViewColor9")!
    static let view_bg_color10: UIColor      = UIColor(named: "ViewColor10")!
    static let system_1:       UIColor      = UIColor(named: "system-1")!
    static let system_2:       UIColor      = UIColor(named: "system-2")!
    // MARK: -通用背景色
    static let public_bg_7: UIColor      = UIColor(named: "public-BG-7")!
    static let public_bg_8: UIColor      = UIColor(named: "public-BG-8")!
}
/// 统一结果态：用它来做日志和灰度
public enum JobsOpenResult {
    case opened                 // 成功触发了系统打开
    case cannotOpen             // 系统认为不能打开（未安装/被限制）
    case invalidInput           // 入参不是一个有效的 URL/电话
}
/// 图片解析错误类型
public enum KFError: Error {
    case badURL          // 非法 URL 或无法解析
    case notFound        // 本地图片不存在
}
/// 统一来源：远程 or 本地
public enum ImageSource {
    case remote(URL)
    case local(String)
}
/// 全覆盖 JSON”模型
public enum JSONValue: Equatable, Codable {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let obj = try? container.decode([String: JSONValue].self) {
            self = .object(obj)
        } else if let arr = try? container.decode([JSONValue].self) {
            self = .array(arr)
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: container.codingPath,
                      debugDescription: "Unsupported JSON value")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        /// 处理 .null 分支
        case .null:
            try container.encodeNil()
        /// 处理 .bool 分支
        case .bool(let b):
            try container.encode(b)
        /// 处理 .int 分支
        case .int(let i):
            try container.encode(i)
        /// 处理 .double 分支
        case .double(let d):
            try container.encode(d)
        /// 处理 .string 分支
        case .string(let s):
            try container.encode(s)
        /// 处理 .object 分支
        case .object(let obj):
            try container.encode(obj)
        /// 处理 .array 分支
        case .array(let arr):
            try container.encode(arr)
        }
    }
}

public enum JobsSymbolWeight {
    case ultraLight,
         thin,
         light,
         regular,
         medium,
         semibold,
         bold,
         heavy,
         black
}

@available(iOS 13.0, *)
extension JobsSymbolWeight {
    public func toSymbolWeight() -> UIImage.SymbolWeight {
        switch self {
        /// 处理 .ultraLight 分支
        case .ultraLight: return .ultraLight
        /// 处理 .thin 分支
        case .thin:       return .thin
        /// 处理 .light 分支
        case .light:      return .light
        /// 处理 .regular 分支
        case .regular:    return .regular
        /// 处理 .medium 分支
        case .medium:     return .medium
        /// 处理 .semibold 分支
        case .semibold:   return .semibold
        /// 处理 .bold 分支
        case .bold:       return .bold
        /// 处理 .heavy 分支
        case .heavy:      return .heavy
        /// 处理 .black 分支
        case .black:      return .black
        }
    }
}
