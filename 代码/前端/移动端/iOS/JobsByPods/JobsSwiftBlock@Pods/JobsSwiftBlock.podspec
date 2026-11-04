Pod::Spec.new do |s|
  s.name         = 'JobsSwiftBlock'          # Pod 名
  s.version      = '0.1.0'
  s.summary      = 'Swift@基础工具集'
  s.description  = <<-DESC
                      关于Swift语言下的基础工具集
                   DESC

  s.homepage     = 'https://github.com/JobsKits/JobsSwiftBlock'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Jobs' => 'lg295060456@gmail.com' }

  s.platform      = :ios, '12.0'
  s.swift_version = '5.0'

  s.source = {
    :git => 'https://github.com/JobsKits/JobsSwiftBlock.git',
    :tag => s.version.to_s
  }

  # 全局排除脚本 / 图标 / 未列入此Pod的文件
  s.exclude_files = [
    '【MacOS】🫘JobsPublishPods.command',
    'Resource/icon.png',
    'LICENSE',
    'README.md'
  ]

  # ====================== 根层基础工具（根目录 Swift） ======================
  s.source_files = '**/*.{swift,h,m,mm}'
  
  # ====================== 系统库依赖：所有代码共享 ======================
  s.ios.frameworks = 'UIKit',
                     'WebKit'
#                     
   s.dependency 'SnapKit'
   s.dependency 'Kingfisher'
   s.dependency 'Moya'

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
