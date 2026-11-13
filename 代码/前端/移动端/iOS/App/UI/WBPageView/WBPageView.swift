//
//  WBPageView.swift
//  WoodpeckerWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit
import SnapKit
import JobsByUIKit
import JobsSwiftDSL
import JobsSwiftBaseDefines

final class WBPageView: UIScrollView {
    private(set) var rows: [UIView] = []
    private lazy var content = WBUI.stack()
    lazy var message = WBUI.label("", size: 13, secondary: true)

    init() {
        super.init(frame: .zero)
        byBackgroundColor(JobsCor.systemGroupedBackground)
            .byKeyboardDismissMode(.onDrag)
            .byShowsVerticalScrollIndicator(false)
        content.byAddTo(self) { [unowned self] make in
            make.top.bottom.equalTo(self.contentLayoutGuide).inset(24)
            make.centerX.equalTo(self.frameLayoutGuide)
            make.width.equalTo(self.frameLayoutGuide).offset(-40).priority(750)
            make.width.lessThanOrEqualTo(760)
            make.leading.trailing.equalTo(self.contentLayoutGuide).inset(20)
        }
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func mount(in controller: UIViewController) {
        byAddTo(controller.view) { make in
            if controller.view.jobs_hasVisibleTopBar() {
                make.top.equalTo(controller.gk_navigationBar.snp.bottom)
                make.leading.trailing.bottom.equalTo(controller.view.safeAreaLayoutGuide)
            } else {
                make.edges.equalTo(controller.view.safeAreaLayoutGuide)
            }
        }
    }

    func replace(_ views: [UIView]) {
        rows.forEach { row in
            content.byRemoveArrangedSubview(row)
            row.byRemoveFromSuperview()
        }
        rows = views
        content.byAddArrangedSubviews(rows)
    }

    func status(_ text: String) {
        message.byText(WBL10n.text(text))
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        WBTheme.sync(with: traitCollection)
    }
}
