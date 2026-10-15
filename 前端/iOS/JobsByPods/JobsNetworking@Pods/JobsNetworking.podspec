Pod::Spec.new do |s|
  s.name         = 'JobsNetworking'
  s.version      = '1.0.1'
  s.summary      = 'A domain-oriented networking layer built on Alamofire with iOS12 Core, iOS13+ Async, and compatibility subspecs.'
  s.description  = <<-DESC
  JobsNetworking vNext with maximum backward compatibility for legacy Podfiles.
  DESC

  s.homepage     = 'https://github.com/JobsKits/JobsNetworking'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Jobs' => 'lg295060456@gmail.com' }
  s.platform     = :ios, '12.0'
  s.swift_versions = ['5.7', '5.8', '5.9', '5.10']
  s.source       = { :git => 'https://github.com/JobsKits/JobsNetworking.git', :tag => s.version.to_s }

  s.exclude_files = [
    'Resource/icon.png',
    'Examples/**/*',
    'Docs/**/*'
  ]

  # Keep the default safe for iOS 12 projects.
  s.default_subspecs = 'Core'

  s.subspec 'Core' do |sp|
    sp.ios.deployment_target = '12.0'
    sp.resource_bundles = { 'JobsNetworkingPrivacy' => ['Resource/PrivacyInfo.xcprivacy'] }
    sp.dependency 'Alamofire', '~> 5.9'
    sp.dependency 'JobsSwiftDSL'
    sp.source_files = [
      'Core/**/*.{swift,h,m,mm}',
      'Support/**/*.{swift,h,m,mm}',
      'Request/**/*.{swift,h,m,mm}',
      'RequestConfig/**/*.{swift,h,m,mm}',
      'Cache/**/*.{swift,h,m,mm}',
      'Agent/**/*.{swift,h,m,mm}',
      'Download/**/*.{swift,h,m,mm}',
      'Upload/**/*.{swift,h,m,mm}',
      'Types/**/*.{swift,h,m,mm}'
    ]
    sp.exclude_files = [
      'Async/**/*',
      'Adapters/**/*',
      'Examples/**/*',
      'Docs/**/*'
    ]
  end

  # Backward-compatible subspec kept for existing Podfiles.
  # Actual AF5 implementation lives in Core.
  s.subspec 'AF5' do |sp|
    sp.ios.deployment_target = '12.0'
    sp.dependency 'JobsNetworking/Core'
    sp.source_files = 'Adapters/AF5.x/**/*.{swift,h,m,mm}'
  end

  # Compatibility-only placeholder to avoid breaking old Podfiles.
  s.subspec 'AF4' do |sp|
    sp.ios.deployment_target = '12.0'
    sp.dependency 'JobsNetworking/Core'
    sp.source_files = 'Adapters/AF4.x/**/*.{swift,h,m,mm}'
  end

  s.subspec 'Async' do |sp|
    sp.ios.deployment_target = '13.0'
    sp.dependency 'JobsNetworking/Core'
    sp.source_files = 'Async/**/*.{swift,h,m,mm}'
  end

  s.subspec 'PromiseKit' do |sp|
    sp.ios.deployment_target = '13.0'
    sp.dependency 'JobsNetworking/Core'
    sp.dependency 'PromiseKit', '~> 8.2'
    sp.source_files = 'Adapters/PromiseKit/**/*.{swift,h,m,mm}'
  end
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

  # Explicit subspec consumers do not inherit the root's file exclusions.
  s.recursive_subspecs.each do |subspec|
    subspec.exclude_files = Array(subspec.attributes_hash['exclude_files']) + Array(s.attributes_hash['exclude_files'])
  end

end
