Pod::Spec.new do |s|
  s.name         = 'JobsSwiftStandardLibrary'          # Pod 名
  s.version      = '0.0.1'
  s.summary      = 'Swift中的一些手搓工具（持续更新）'
  s.description  = <<-DESC
                      Swift.Foundation.Extensions
                   DESC

  s.homepage     = 'https://github.com/JobsKits/JobsSwiftStandardLibrary'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Jobs' => 'lg295060456@gmail.com' }

  s.platform     = :ios, '12.0'
  s.swift_version = '5.0'

  # 你的源码从 Git 仓库下载
  s.source       = { :git => 'https://github.com/JobsKits/JobsSwiftStandardLibrary.git',
                     :tag => s.version.to_s }

  # 递归匹配当前目录下所有子目录里的 .swift 文件
  s.source_files = '**/*.{swift,h,m,mm}'

  # 全局排除脚本 / 图标
  s.exclude_files = [
    '【MacOS】🫘JobsPublishPods.command',
    'Resource/icon.png',
    'LICENSE',
  ]
  s.dependency 'JobsSwiftBaseDefines'
  
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
