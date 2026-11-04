Pod::Spec.new do |s|
  s.name         = 'JobsToast'          # Pod 名
  s.version      = '0.1.14'
  s.summary      = 'Swift@基础工具集'
  s.description  = <<-DESC
                      关于Swift语言下的基础工具集
                   DESC

  s.homepage     = 'https://github.com/JobsKits/JobsToast'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Jobs' => 'lg295060456@gmail.com' }

  s.platform      = :ios, '12.0'
  s.swift_version = '5.0'

  s.source = {
    :git => 'https://github.com/JobsKits/JobsToast.git',
    :tag => s.version.to_s
  }

  # 全局排除脚本 / 图标
  s.exclude_files = [
    '【MacOS】🫘JobsPublishPods.command',
    'Resource/icon.png',
    'LICENSE',
  ]

  s.source_files = '**/*.{swift,h,m,mm}'

  # ====================== 系统库依赖：所有代码共享 ======================
  s.ios.frameworks = 'UIKit'

  # ====================== 第三方依赖：所有代码共享 ======================
  s.dependency 'SnapKit'
  s.dependency 'JobsByUIKit'
  s.dependency 'JobsSwiftBlock'
  s.dependency 'JobsSwiftBaseDefines'
    s.dependency 'JobsSwiftDSL'

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

end
