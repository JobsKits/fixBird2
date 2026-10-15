# 自述：按真实 App/Tests 目录增量维护 Xcode 引用，不安装 Pods、不调用构建或部署。
require 'xcodeproj'
require 'pathname'

root = File.expand_path('..', __dir__)
project_path = File.join(root, 'RepairWorkbench.xcodeproj')
project = File.directory?(project_path) ? Xcodeproj::Project.open(project_path) : Xcodeproj::Project.new(project_path)
app = project.targets.find { |target| target.name == 'RepairWorkbench' }
app ||= project.new_target(:application, 'RepairWorkbench', :ios, '15.0')
tests = project.targets.find { |target| target.name == 'RepairWorkbenchTests' }
tests ||= project.new_target(:unit_test_bundle, 'RepairWorkbenchTests', :ios, '15.0')
tests.add_dependency(app) unless tests.dependencies.any? { |dependency| dependency.target == app }
project.root_object.attributes['LastUpgradeCheck'] = '2700'
project.root_object.attributes['LastSwiftUpdateCheck'] = '2700'
project.root_object.known_regions = ['zh-Hans', 'en', 'Base']

# 只添加不存在的引用，重复执行保留 CocoaPods 集成和原对象 UUID。
def add_reference(project, root, relative)
  folder = project.main_group
  parts = relative.split('/')
  parts[0...-1].each do |part|
    child = folder.groups.find { |group| group.path == part }
    child ||= folder.new_group(part, part)
    folder = child
  end
  folder.files.find { |reference| reference.path == parts.last } || folder.new_file(parts.last)
end

Dir.glob(File.join(root, 'App/**/*.swift')).sort.each do |file|
  relative = Pathname.new(file).relative_path_from(Pathname.new(root)).to_s
  reference = add_reference(project, root, relative)
  app.source_build_phase.add_file_reference(reference, true)
end
Dir.glob(File.join(root, 'Tests/Data/**/*.swift')).sort.each do |file|
  relative = Pathname.new(file).relative_path_from(Pathname.new(root)).to_s
  reference = add_reference(project, root, relative)
  tests.source_build_phase.add_file_reference(reference, true)
end
['App/Resource/Assets.xcassets', 'App/Resource/JobsThemeResources.json', 'App/Resource/PrivacyInfo.xcprivacy'].each do |relative|
  next unless File.exist?(File.join(root, relative))
  reference = add_reference(project, root, relative)
  app.resources_build_phase.add_file_reference(reference, true)
end
['App/Resource/Info.Debug.plist', 'App/Resource/Info.Release.plist', 'README.md', 'Podfile', 'Podfile.deps'].each do |relative|
  next unless File.exist?(File.join(root, relative))
  reference = add_reference(project, root, relative)
  reference.explicit_file_type = 'text.script.ruby' if ['Podfile', 'Podfile.deps'].include?(relative)
end

[app, tests].each do |target|
  target.build_configurations.each do |configuration|
    settings = configuration.build_settings
    settings['SWIFT_VERSION'] = '5.0'
    settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    settings['SWIFT_STRICT_CONCURRENCY'] = 'minimal'
    settings['CLANG_ENABLE_MODULES'] = 'YES'
    settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    settings['CODE_SIGN_STYLE'] = 'Automatic'
    settings['GENERATE_INFOPLIST_FILE'] = 'YES' if target == tests
    settings['SWIFT_OPTIMIZATION_LEVEL'] = configuration.name == 'Debug' ? '-Onone' : '-O'
    settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG $(inherited)' if configuration.name == 'Debug'
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = target == app ? 'com.jobs.woodpecker.workbench' : 'com.jobs.woodpecker.workbench.tests'
    settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
    settings['MARKETING_VERSION'] = '3.8.0'
    settings['CURRENT_PROJECT_VERSION'] = '1'
    if target == app
      settings['INFOPLIST_FILE'] = configuration.name == 'Debug' ? 'App/Resource/Info.Debug.plist' : 'App/Resource/Info.Release.plist'
      settings['GENERATE_INFOPLIST_FILE'] = 'NO'
      settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
      settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks'
    else
      settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/RepairWorkbench.app/RepairWorkbench'
      settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
    end
  end
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(tests)
scheme.set_launch_target(app)
scheme.test_action.build_configuration = 'Debug'
scheme.save_as(project_path, 'RepairWorkbench', true)
reopened = Xcodeproj::Project.open(project_path)
raise '工程根对象失效' unless reopened.root_object.isa == 'PBXProject'
puts "Xcode引用已维护：App #{app.source_build_phase.files.length}，Tests #{tests.source_build_phase.files.length}。"
