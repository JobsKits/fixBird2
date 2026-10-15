//
//  UIViewController+SnapKit.swift
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

#if canImport(SnapKit)
import SnapKit
/// 利用SnapKit 给 UIViewController 加背景图（UIImageView）
extension UIViewController {
    // MARK: - AO Key（UInt8 哨兵）
    private struct _JobsAssocKeys {
        static var imageView: UInt8 = 0
    }
    // MARK: - 懒载 imageView（挂在 VC 上）
    public var jobsImageView: UIImageView {
        if let iv = objc_getAssociatedObject(self, &_JobsAssocKeys.imageView) as? UIImageView {
            return iv
        }
        let iv = UIImageView().byUserInteractionEnabled(false).byClipsToBounds(true).byContentMode(.scaleAspectFill)
        objc_setAssociatedObject(self, &_JobsAssocKeys.imageView, iv, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return iv
    }
    // MARK: - 安装并约束（默认铺满 Safe Area）
    @discardableResult
    public func bgImageView(
        to container: UIView? = nil,
        contentMode: UIView.ContentMode = .scaleAspectFill,
        backgroundColor: UIColor? = nil,
        remakeConstraints: Bool = true,
        layout: (jobsByConstraintMakerBlock)? = nil
    ) -> UIImageView {
        let holder = container ?? view
        let iv = jobsImageView
        if iv.superview !== holder {
            iv.removeFromSuperview()
            holder?.addSubview(iv)
        }
        iv.byContentMode(contentMode)
        if let bg = backgroundColor { iv.backgroundColor = bg }
        if let layout = layout {
            if remakeConstraints { iv.snp.remakeConstraints(layout) }
            else { iv.snp.makeConstraints(layout) }
        } else {
            if remakeConstraints {
                iv.snp.remakeConstraints { make in
                    if let holder = holder {
                        make.edges.equalTo(holder.safeAreaLayoutGuide)
                    } else {
                        make.edges.equalToSuperview()
                    }
                }
            } else {
                iv.snp.makeConstraints { make in
                    if let holder = holder {
                        make.edges.equalTo(holder.safeAreaLayoutGuide)
                    } else {
                        make.edges.equalToSuperview()
                    }
                }
            }
        }
        view.sendSubviewToBack(iv)
        return iv
    }
    // MARK: - 卸载
    public func removeJobsImageView() {
        jobsImageView.removeFromSuperview()
    }
}
#endif
