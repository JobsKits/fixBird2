Pod::Spec.new do |s|
  s.name         = 'JobsSwiftBaseDefines'          # Pod 名
  s.version      = '0.1.6'
  s.summary      = '一些全局的基础定义'
  s.description  = <<-DESC
                      全局常量/协议定义/结构体/枚举
                   DESC
  s.homepage     = 'https://github.com/JobsKits/JobsSwiftBaseDefines'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Jobs' => 'lg295060456@gmail.com' }

  s.platform     = :ios, '12.0'
  s.swift_version = '5.0'
  s.source       = { :git => 'https://github.com/JobsKits/JobsSwiftBaseDefines.git',
                     :tag => s.version.to_s }
  s.source_files = '**/*.{swift,h,m,mm}'
  s.ios.frameworks = 'UIKit'
  
  s.dependency 'JobsSwiftBlock'
  s.dependency 'JobsTextTools'
  
  # 全局排除脚本 / 图标
  s.exclude_files = [
    '【MacOS】🫘JobsPublishPods.command',
    'Resource/icon.png',
    'LICENSE',
  ]

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
  s.resource_bundles = (s.attributes_hash['resource_bundles'] || {}).merge('JobsSwiftBaseDefinesPrivacy' => ['Resource/PrivacyInfo.xcprivacy'])

end
