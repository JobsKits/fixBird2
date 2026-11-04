//
//  UIView+SnapKit.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBlock
import JobsSwiftDSL
import JobsSwiftBaseDefines

// MARK: - SnapKit

#if canImport(SnapKit)
import SnapKit
private var addClosureKey: UInt8 = 0
extension UIView {
    public var jobsAddConstraintsClosure: jobsByConstraintMakerBlock? {
        get {
            objc_getAssociatedObject(self, &addClosureKey) as? jobsByConstraintMakerBlock
        }
        set {
            // 闭包推荐 COPY 语义
            objc_setAssociatedObject(
                self,
                &addClosureKey,
                newValue,
                .OBJC_ASSOCIATION_COPY_NONATOMIC
            )
        }
    }
    // MARK: - 存储约束
    @discardableResult
    public func byAddConstraintsClosure(_ closure: ((_ make: ConstraintMaker) -> Void)? = nil) -> Self {
        if let closure {
            self.jobsAddConstraintsClosure = closure
        };return self
    }
    // MARK: - 添加约束
    @discardableResult
    public func byAdd(_ closure: ((_ make: ConstraintMaker) -> Void)? = nil) -> Self {
        if let closure {
            self.byAddConstraintsClosure(closure)
            self.snp.makeConstraints(closure)
        };return self
    }
    // MARK: - 添加到父视图
    /**
     
         .byAddTo(view) { [unowned self] make in
             /// TODO
         }
     */
    // 基础的一参数 byAddTo 位于 JobsSwiftDSL；这里仅承接 SnapKit 约束。
    @discardableResult
    public func byAddTo(
        _ superView: UIView?,
        _ closure: ((ConstraintMaker) -> Void)?
    ) -> Self {
        guard let superView else { return self }
        superView.addSubview(self)
        if let closure {
            self.snp.makeConstraints(closure)
        };return self
    }
    /**
     
         UI.byAddTo(view) { v, make in
             /// TODO
         }
     */
    // ✅ 必须传 closure（不提供默认值），避免歧义
    @discardableResult
    public func byAddTo(
        _ superView: UIView?,
        _ closure: (_ v: UIView, _ make: ConstraintMaker) -> Void
    ) -> Self {
        guard let superView else { return self }
        superView.addSubview(self)
        self.snp.makeConstraints { make in
            closure(self, make)
        };return self
    }
    /// 把当前 view 作为 arrangedSubview 加入 stackView，并支持链式 + 可选约束
    @discardableResult
    public func byArrangedTo(
        _ container: UIStackView?,
        _ closure: ((ConstraintMaker) -> Void)? = nil
    ) -> Self {
        guard
            let stackView = container as? UIStackView
        else { return self }
        stackView.addArrangedSubview(self)
        if let closure {
            self.snp.makeConstraints(closure)
        };return self
    }
    // MARK: - 链式 makeConstraints
    @discardableResult
    public func byMakeConstraints(_ closure: @escaping (_ make: ConstraintMaker) -> Void) -> Self {
        self.byAddConstraintsClosure(closure)
        self.snp.makeConstraints(closure)
        return self
    }
    // MARK: - 链式 remakeConstraints（先移除旧约束，再添加新约束）
    @discardableResult
    public func byRemakeConstraints(_ closure: @escaping (_ make: ConstraintMaker) -> Void) -> Self {
        self.byAddConstraintsClosure(closure)
        self.snp.remakeConstraints(closure)
        return self
    }
    // MARK: - 链式 updateConstraints（更新之前的约束，要求一定要和之前的约束匹配的上，否则崩溃）
    @discardableResult
    public func byUpdateConstraints(_ closure: @escaping (_ make: ConstraintMaker) -> Void) -> Self {
        self.byAddConstraintsClosure(closure)
        self.snp.updateConstraints(closure)
        return self
    }
    // MARK: - 链式 removeConstraints
    @discardableResult
    public func byRemoveConstraints() -> Self {
        self.byAddConstraintsClosure(nil)
        self.snp.removeConstraints()
        return self
    }
}
/**
 
     // MARK: - 水平 / 垂直 均分排布
     private lazy var btnArr = [fundsBtn, recordsBtn, rulesBtn, resultsBtn] as [JobsButton]
     btnArr.addDistributeTo(
         btnBgView.byVisible(true),                 // ✅ 把 btnBgView 显示出来，并作为承载容器
         model: SnapDistributeModel(
             axis: .horizontal,                     // ✅ 分布方向：horizontal=横向一排，vertical=纵向一列
             fixedItemLength: nil,                  // ✅ 固定 item 宽/高（沿 axis 的长度）
                                                    //    nil = 不固定，改为“均分”（宽度/高度相等）
                                                    //    horizontal -> 固定宽度
                                                    //    vertical   -> 固定高度
             leadSpacing: 12.w,                     // ✅ 头部间距（第一个 item 到容器边的距离）
                                                    //    horizontal -> 左边距
                                                    //    vertical   -> 上边距
             tailSpacing: 12.w,                     // ✅ 尾部间距（最后一个 item 到容器边的距离）
                                                    //    horizontal -> 右边距
                                                    //    vertical   -> 下边距
             makeContainerConstraints: false,       // ✅ 是否顺便给“容器本身”补约束（一般不需要）
                                                    //    true  -> 这个 distribute 方法会额外对容器加 top/bottom/crossSize 等约束
                                                    //    false -> 只给 items 加约束（推荐，容器约束由外部负责）
             top: 12.h,                             // ✅ 交叉方向上边距
                                                    //    horizontal -> item 的 top inset
                                                    //    vertical   -> 无意义（通常用 left/right）
             bottom: 12.h,                          // ✅ 交叉方向下边距
                                                    //    horizontal -> item 的 bottom inset
                                                    //    vertical   -> 无意义（通常用 left/right）
             left: nil,                             // ✅ 交叉方向左边距
                                                    //    vertical -> item 的 left inset
                                                    //    horizontal -> 通常不用（横向用 top/bottom）
             right: nil,                            // ✅ 交叉方向右边距
                                                    //    vertical -> item 的 right inset
                                                    //    horizontal -> 通常不用（横向用 top/bottom）
             crossSize: nil                         // ✅ 交叉方向固定尺寸
                                                    //    horizontal -> 固定 item 高度 height
                                                    //    vertical   -> 固定 item 宽度 width
                                                    //    nil -> 不固定，交叉方向用 top/bottom 或 left/right 拉伸
         )
     )
 */
extension UIView {
    /// SnapKit 版 distributeViewsAlongAxis
    /// - Parameters:
    ///   - views: 要分布的子视图（需要先 addSubview）
    ///   - model: 分布参数
    @discardableResult
    public func snap_distribute(_ views: [UIView], _ model: SnapDistributeModel) -> Self {
        guard views.count >= 2 else {
            // 只有 0/1 个 view，不需要 distribute
            if let v = views.first {
                if model.axis == .horizontal {
                    v.snp.makeConstraints { make in
                        make.left.equalToSuperview().inset(model.leadSpacing)
                        make.right.equalToSuperview().inset(model.tailSpacing)
                        make.top.bottom.equalToSuperview()
                    }
                } else {
                    v.snp.makeConstraints { make in
                        make.top.equalToSuperview().inset(model.leadSpacing)
                        make.bottom.equalToSuperview().inset(model.tailSpacing)
                        make.left.right.equalToSuperview()
                    }
                }
            };return self
        }
        switch model.axis {
        /// 处理 .horizontal 分支
        case .horizontal:
            // 头尾
            views.first!.snp.makeConstraints { make in
                make.left.equalToSuperview().inset(model.leadSpacing)
            }
            views.last!.snp.makeConstraints { make in
                make.right.equalToSuperview().inset(model.tailSpacing)
            }
            // 串起来 + 同高（或 crossSize）
            for i in 0..<views.count {
                let v = views[i]
                v.snp.makeConstraints { make in
                    // 顶底拉伸（或 crossSize 固定高度）
                    if let top = model.top { make.top.equalToSuperview().inset(top) }
                    if let bottom = model.bottom { make.bottom.equalToSuperview().inset(bottom) }
                    if let h = model.crossSize { make.height.equalTo(h) }
                }
                if i > 0 {
                    v.snp.makeConstraints { make in
                        make.left.equalTo(views[i - 1].snp.right)
                    }
                }
                // 固定 itemLength 或 均分（宽度相等）
                if let w = model.fixedItemLength {
                    v.snp.makeConstraints { make in
                        make.width.equalTo(w)
                    }
                } else if i > 0 {
                    v.snp.makeConstraints { make in
                        make.width.equalTo(views[0])
                    }
                }
            }
            // 可选：容器自身约束（像 Masonry 那段）
            if model.makeContainerConstraints {
                self.snp.makeConstraints { make in
                    if let top = model.top { make.top.equalToSuperview().inset(top) }
                    if let bottom = model.bottom { make.bottom.equalToSuperview().inset(bottom) }
                    if let h = model.crossSize { make.height.equalTo(h) }
                }
            }
        /// 处理 .vertical 分支
        case .vertical:
            views.first!.snp.makeConstraints { make in
                make.top.equalToSuperview().inset(model.leadSpacing)
            }
            views.last!.snp.makeConstraints { make in
                make.bottom.equalToSuperview().inset(model.tailSpacing)
            }
            for i in 0..<views.count {
                let v = views[i]
                v.snp.makeConstraints { make in
                    if let left = model.left { make.left.equalToSuperview().inset(left) }
                    if let right = model.right { make.right.equalToSuperview().inset(right) }
                    if let w = model.crossSize { make.width.equalTo(w) }
                }
                if i > 0 {
                    v.snp.makeConstraints { make in
                        make.top.equalTo(views[i - 1].snp.bottom)
                    }
                }
                if let h = model.fixedItemLength {
                    v.snp.makeConstraints { make in
                        make.height.equalTo(h)
                    }
                } else if i > 0 {
                    v.snp.makeConstraints { make in
                        make.height.equalTo(views[0])
                    }
                }
            }
            if model.makeContainerConstraints {
                self.snp.makeConstraints { make in
                    if let left = model.left { make.left.equalToSuperview().inset(left) }
                    if let right = model.right { make.right.equalToSuperview().inset(right) }
                    if let w = model.crossSize { make.width.equalTo(w) }
                }
            }
        };return self
    }
}

// MARK: - ✅ btnArr 链式：addSubview + distribute
extension Array where Element: UIView {
    /// 把数组里的 view 全部 add 到 superView（链式返回 self）
    @discardableResult
    public func addTo(_ superView: UIView) -> Self {
        forEach { superView.addSubview($0) };return self
    }
    /// 在 superView 内对数组 view 做均分分布（链式返回 self）
    /// 注意：默认要求已经 addSubview 进 superView（可配合 jobs_addTo）
    @discardableResult
    public func snapDistribute(in superView: UIView, model: SnapDistributeModel) -> Self {
        superView.snap_distribute(self, model)
        return self
    }
    /// 一步到位：addTo + distribute
    @discardableResult
    public func addDistributeTo(_ superView: UIView, model: SnapDistributeModel) -> Self {
        addTo(superView)
        snapDistribute(in: superView, model: model)
        return self
    }
}
#endif
