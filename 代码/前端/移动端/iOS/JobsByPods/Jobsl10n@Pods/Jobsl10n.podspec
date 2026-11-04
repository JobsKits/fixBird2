Pod::Spec.new do |s|
  s.name         = 'Jobsl10n'          # Pod 名
  s.version      = '0.1.14'
  s.summary      = 'Swift@多语言国际化'
  s.description  = <<-DESC
                     Swift@多语言国际化
                   DESC

  s.homepage     = 'https://github.com/JobsKits/Jobsl10n'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Jobs' => 'lg295060456@gmail.com' }

  s.platform      = :ios, '12.0'
  s.swift_version = '5.0'
  
  # 全局排除脚本 / 图标
  s.exclude_files = [
    '【MacOS】🫘JobsPublishPods.command',
    'Resource/icon.png',
    'LICENSE',
  ]

  s.source = {
    :git => 'https://github.com/JobsKits/Jobsl10n.git',
    :tag => s.version.to_s
  }

  s.source_files = '**/*.{swift,h,m,mm}'
  s.ios.frameworks = 'UIKit'
  
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
  s.resource_bundles = (s.attributes_hash['resource_bundles'] || {}).merge('Jobsl10nPrivacy' => ['Resource/PrivacyInfo.xcprivacy'])

end
