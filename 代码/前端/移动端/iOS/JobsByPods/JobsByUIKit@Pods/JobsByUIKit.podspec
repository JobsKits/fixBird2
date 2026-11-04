Pod::Spec.new do |s|
  s.name         = 'JobsByUIKit'          # Pod 名
  s.version      = '0.0.1'
  s.summary      = 'Swift中，对UIKit进行的拓展（持续更新中）'
  s.description  = <<-DESC
                      JobsByUIKit
                   DESC

  s.homepage     = 'https://github.com/JobsKits/JobsByUIKit'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Jobs' => 'lg295060456@gmail.com' }

  s.platform     = :ios, '12.0'
  s.swift_version = '5.0'

  # 你的源码从 Git 仓库下载
  s.source       = { :git => 'https://github.com/JobsKits/JobsByUIKit.git',
                     :tag => s.version.to_s }
                     
  # 全局排除脚本 / 图标
  s.exclude_files = [
    '【MacOS】🫘JobsPublishPods.command',
    'Resource/icon.png',
    'LICENSE',
#    '**/UIView+Lottie.swift',       # 低版本的 Lottie 没有 LottieAnimationView
#    '**/UIView+keyboard.swift',     # 低版本的Rx不兼容
#    '**/UIView+Rx.swift',           # 低版本的Rx不兼容
#    '**/UITextField+Rx.swift',      # 低版本的Rx不兼容
#    '**/UITextView+监控删除键.swift', # 低版本的Rx不兼容
#    '**/UITextField+监控输入.swift',  # 低版本的Rx不兼容
#    '**/UITextView+监控输入.swift',   # 低版本的Rx不兼容
  ]
  
  s.ios.frameworks = 'UIKit',
                     'PhotosUI',
                     'WebKit',
                     'MessageUI',
                     'CoreImage'
  # 递归匹配当前目录下所有子目录里的 .swift 文件
  s.source_files = '**/*.{swift,h,m,mm}'
  s.dependency 'Kingfisher'
  s.dependency 'GKNavigationBarSwift'
  s.dependency 'SnapKit'
  s.dependency 'SVGKit'
  s.dependency 'ESPullToRefresh'
  s.dependency 'RxSwift'
  s.dependency 'RxCocoa'
  s.dependency 'RxRelay'
  s.dependency 'NSObject+Rx'
  s.dependency 'SkeletonView'
  s.dependency 'lottie-ios'
  s.dependency 'Jobsl10n'
  s.dependency 'JobsScale'
  s.dependency 'JobsNavBar'
  s.dependency 'JobsTextTools'
  s.dependency 'JobsSwiftTimer'
  s.dependency 'JobsSwiftBlock'
  s.dependency 'JobsImageTools'
  s.dependency 'JobsByQuartzCore'
  s.dependency 'JobsSwiftBaseDefines'
  s.dependency 'JobsViewPush'
  s.dependency 'JobsSwiftDSL'
  s.dependency 'JobsGetWindow'

  # Jobs production boundary: keep validation and temporary sources out of release targets.
  s.exclude_files = Array(s.attributes_hash['exclude_files']) + [
    '**/Tests/**/*',
    '**/Test/**/*',
    '**/Example/**/*',
    '**/Examples/**/*',
    '**/Demo/**/*',
    '**/Demos/**/*',
    '**/build/**/*',
    '**/DerivedData/**/*',
    '**/*Tests.swift',
    '**/*UITests.swift',
    '**/*.tmp.*',
  ]
  s.resource_bundles = (s.attributes_hash['resource_bundles'] || {}).merge('JobsByUIKitPrivacy' => ['Resource/PrivacyInfo.xcprivacy'])

end
