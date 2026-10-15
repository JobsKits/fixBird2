//
//  JobsSwiftBaseBlock.swift
//  JobsSwiftBlock
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC
import WebKit

// MARK: —— CreatedBy@Jobs
/// 全局@基础
public typealias jobsByVoidBlock = () -> Void
public typealias jobsByAnyBlock = (Any?) -> Void
public typealias jobsByAnyVoidBlock = (Any) -> Void
public typealias jobsByAnyArgsVoidBlock = ([Any]) -> Void
public typealias jobsByAnyTransformBlock = (Any) -> Any
public typealias jobsByTypeBlock<T> = (T?) -> Void

public typealias jobsByNonNullTypeBlock<T> = (T) -> Void
public typealias jobsByOwnerArgBlock<Owner, Arg> = (Owner, Arg) -> Void
public typealias jobsByOwnerRetBlock<Owner, R> = (Owner) -> R
public typealias jobsByOwnerArgRetBlock<Owner, Arg, R> = (Owner, Arg) -> R
public typealias jobsByArgBlock<Arg> = (Arg) -> Void
public typealias JobsRetOptionalTByVoidBlock<T> = () -> T?
public typealias JobsRetOptionalTByArgBlock<Arg, T> = (Arg) -> T?
public typealias jobsByCurriedOwnerRetBlock<Owner, R> = (Owner) -> () -> R
public typealias jobsByCurriedOwnerArgRetBlock<Owner, Arg, R> = (Owner) -> (Arg) -> R

public typealias jobsByBoolBlock = (Bool?) -> Void
public typealias jobsByBOOLBlock = (Bool) -> Void

public typealias jobsByintBlock = (Int?) -> Void
public typealias jobsByIntBlock = (Int) -> Void

public typealias jobsBycgFloatBlock = (CGFloat?) -> Void
public typealias jobsByCGFloatBlock = (CGFloat) -> Void

public typealias jobsByCGRectBlock = (CGRect?) -> Void
public typealias jobsByFrameBlock = (CGRect) -> Void
public typealias jobsByCGPointBlock = (CGPoint?) -> Void
public typealias jobsByPointBlock = (CGPoint) -> Void
public typealias jobsByCGSizeBlock = (CGSize?) -> Void
public typealias jobsBySizeBlock = (CGSize) -> Void

public typealias jobsByURLBlock = (URL?) -> Void
public typealias jobsByUrlBlock = (URL) -> Void
public typealias jobsByURLsBlock = ([URL]?) -> Void
public typealias jobsByUrlsBlock = ([URL]) -> Void
public typealias jobsByNotificationBlock = (Notification?) -> Void
public typealias jobsByNotiBlock = (Notification) -> Void
public typealias jobsByStringBlock = (String?) -> Void
public typealias jobsByStrBlock = (String) -> Void
public typealias jobsByButtonBlock = (UIButton?) -> Void
public typealias jobsByBtnBlock = (UIButton) -> Void
public typealias jobsByImageBlock = (UIImage?) -> Void
public typealias jobsByImgBlock = (UIImage) -> Void
public typealias jobsByTextFieldBlock = (UITextField) -> Void
public typealias jobsByBarButtonItemBlock = (UIBarButtonItem?) -> Void
public typealias jobsByBarBtnItemBlock = (UIBarButtonItem) -> Void
public typealias jobsByGestureRecognizerBlock = (UIGestureRecognizer?) -> Void
public typealias jobsByGRBlock = (UIGestureRecognizer) -> Void
@available(iOS 8.0, *)
public typealias jobsByWKWebConfigurationBlock = (WKWebViewConfiguration?) -> Void
@available(iOS 8.0, *)
public typealias jobsByWKWebConfigBlock = (WKWebViewConfiguration) -> Void
public typealias jobsByDateFormatterBlock = (DateFormatter) -> Void
public typealias jobsByNumberFormatterBlock = (NumberFormatter) -> Void
public typealias jobsByNSUserActivityBlock = (NSUserActivity) -> Void
@available(iOS 13.0, *)
public typealias jobsByNavigationBarAppearanceBlock = (UINavigationBarAppearance) -> Void
@available(iOS 13.0, *)
public typealias jobsByBarButtonItemAppearanceBlock = (UIBarButtonItemAppearance) -> Void
public typealias jobsByNavigationPolicyBlock = (WKNavigationActionPolicy) -> Void
public typealias jobsByCATransitionBlock = (CATransition) -> Void
public typealias jobsByCAAnimationBlock = (CAAnimation) -> Void
public typealias jobsByUIViewBlock = (UIView?) -> Void
public typealias jobsByViewBlock = (UIView) -> Void
@available(iOS 13.0, *)
public typealias jobsByUIContextMenuInteractionBlock = (UIContextMenuInteraction?) -> Void
@available(iOS 13.0, *)
public typealias jobsByContextMenuInteractionBlock = (UIContextMenuInteraction) -> Void
public typealias JobsYTKProgress = (_ progress: Progress) -> Void
public typealias jobsByAnyStringBlock = (Any?, String?) -> Void
public typealias MobileActionBlock = (_ body: [String: Any], _ reply: @escaping jobsByAnyBlock) -> Void
public typealias NativeBlock = (_ payload: Any?, _ reply: @escaping jobsByAnyBlock) -> Void
public typealias jobsByNotiObjUserInfoBlock = (_ noti: Any?, _ obj: AnyObject?, _ userInfo: [AnyHashable: Any]?) -> Void
public typealias JobsRetStringByCGFloatBlock = (CGFloat) -> String
/// 全局@泛型
public typealias JobsRetTByVoidBlock<T> = () -> T
/// 全局@inout
@available(iOS 14.0, *)
public typealias jobsByInoutListContentConfigBlock = (inout UIListContentConfiguration) -> Void
@available(iOS 14.0, *)
public typealias jobsByInoutBackgroundConfigurationBlock = (inout UIBackgroundConfiguration) -> Void
public typealias jobsByInoutWKWebConfigBlock = (inout WKWebViewConfiguration) -> Void
/// 全局@MainActor
public typealias JobsByAnyErrMASendableBlock = @MainActor @Sendable (Any?, Error?) -> Void
public typealias JobsByTMASendableBlock<T: Sendable> = @MainActor @Sendable (T) -> Void
public typealias JobsByMAVoidBlock = @MainActor () -> Void
/// UI@输入控件
/// 限长状态变化时的回调
/// isLimited = true  : 进入“被限长”状态（尝试超出时被拦截）
/// isLimited = false : 从“被限长”状态恢复（删到 maxLength 以下）
public typealias JobsTFOnLimitChanged = (_ isLimited: Bool, _ textField: UITextField) -> Void
public typealias UITextFieldOnChange = (_ tf: UITextField,
                                        _ input: String,
                                        _ oldText: String,
                                        _ isDeleting: Bool) -> Void
public typealias TVOnBackspace = (_ tv: UITextView) -> Void
public typealias TVOnChange = (_ tv: UITextView,
                               _ input: String,
                               _ old: String,
                               _ isDeleting: Bool) -> Void
/// UI@UIButton
public typealias JobsRetButtonBlock = () -> UIButton?         // 返回 nil 隐藏
public typealias JobsButtonLongPressBlock = (UIButton, UILongPressGestureRecognizer) -> Void
public typealias JobsPressFuseTick = (_ btn: UIButton,
                                      _ elapsed: TimeInterval,
                                      _ progress: CGFloat) -> Void
public typealias JobsPressFuseEnd  = (_ btn: UIButton,
                                      _ elapsed: TimeInterval,
                                      _ progress: CGFloat) -> Void
/// UI@图片
public typealias JobsRetUIImageBlock = () -> UIImage?
/// UI@富文本
public typealias JobsRetAttributedString = () -> NSAttributedString?    // 返回 nil 隐藏
/// Data@网络请求
public typealias JobsRetStringByURLRequestBlock = (URLRequest) -> String?
/// UI@其他
@available(iOS 14.0, *)
public typealias JobsRetByListContentConfigBlock = (UIListContentConfiguration) -> UIListContentConfiguration
public typealias JobsRetViewsByVoidBlock = () -> [UIView]
