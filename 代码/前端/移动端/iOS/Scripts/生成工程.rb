# 自述：按真实 App/Tests 目录增量维护 Xcode 引用，不安装 Pods、不调用构建或部署。
# JOBS_TERMINAL_STYLE_GUARD_V1_BEGIN
if $PROGRAM_NAME == __FILE__
  # 直接运行时由 fork 父进程保护配色；子进程继续原文件，不重放 Ruby 参数和预载模块。
  def jobs_terminal_style_bootstrap_v1
    return unless $PROGRAM_NAME == __FILE__
    plain = lambda do
      ENV.update('PLAIN_OUTPUT' => '1', 'NO_COLOR' => '1', 'FORCE_COLOR' => '0',
                 'CLICOLOR' => '0', 'ANSI_COLORS_DISABLED' => '1', 'npm_config_color' => 'false')
    end
    notify = lambda do |message|
      encoding = $stderr.external_encoding || Encoding::UTF_8
      $stderr.write((message + "\n").encode(encoding, invalid: :replace, undef: :replace))
    end
    return unless $stdin.tty? && $stdout.tty?
    return if ENV.key?('NO_COLOR') || ENV['PLAIN_OUTPUT'] == '1' ||
              ENV['IS_SOURCETREE_RUNTIME'] == '1' ||
              ENV.keys.any? { |key| key.match?(/\A(?:SOURCETREE|SOURCE_TREE)/i) }
    return if ['', 'dumb'].include?(ENV.fetch('TERM', ''))
    if File::ALT_SEPARATOR == '\\' || !Process.respond_to?(:fork) ||
       Thread.list.length > 1 || ENV['TMUX'] || ENV['STY']
      plain.call
      return
    end
    tty_name = IO.popen(['tty'], err: File::NULL, &:read).strip
    groups = IO.popen(['ps', '-o', 'pgid=', '-o', 'tpgid=', '-p', Process.pid.to_s], err: File::NULL, &:read).split
    unless tty_name.match?(%r{\A/dev/[A-Za-z0-9_./-]+\z}) && groups.length == 2 &&
           groups.all? { |group| group.match?(/\A\d+\z/) } && groups[0].to_i > 0 && groups[0] == groups[1]
      plain.call
      return
    end
    owner = ENV['JOBS_TERMINAL_STYLE_OWNER']
    if ENV['JOBS_TERMINAL_STYLE_TTY'] == tty_name && owner && owner.match?(/\A\d+\z/)
      begin
        Process.kill(0, owner.to_i)
        return
      rescue Errno::ESRCH, Errno::EPERM
      end
    end
    require 'io/console'
    require 'tmpdir'
    if Thread.list.length > 1
      plain.call
      return
    end
    tty = File.open('/dev/tty', 'r+')
    tty.binmode
    tty.sync = true
    keys = ['10', '11', '12'] + (0..15).map { |index| "4;#{index}" }
    palette = %w[000000 ff5f56 5fd787 ffd75f 5fafff d787ff 5fd7ff eeeeee
                 9e9e9e ff8787 87ffaf ffff87 87bfff ffafff afffff ffffff]
    targets = { '10' => 'ffffff', '11' => '000000', '12' => 'ffffff' }
    palette.each_with_index { |color, index| targets["4;#{index}"] = color }
    query = lambda do |key|
      tty.write("\e]#{key};?\a")
      bytes = ''.b
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 0.3
      loop do
        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        return nil if remaining <= 0 || !IO.select([tty], nil, nil, remaining)
        piece = tty.read_nonblock(256, exception: false)
        next if piece == :wait_readable
        return nil unless piece && !piece.empty?
        bytes << piece
        return nil if bytes.bytesize > 256 || !bytes.start_with?("\e".b)
        break if bytes.end_with?("\a".b) || bytes.end_with?("\e\\".b)
      end
      match = bytes.match(/\A\e\]#{Regexp.escape(key)};rgb:([0-9a-fA-F]{1,4})\/([0-9a-fA-F]{1,4})\/([0-9a-fA-F]{1,4})(?:\a|\e\\)\z/n)
      return nil unless match
      components = match.captures.map { |hex| (hex.to_i(16) * 65535.0 / (16**hex.length - 1)).round }
      { raw: bytes, rgb: components }
    rescue IOError, SystemCallError
      nil
    end
    snapshot = lambda do
      values = {}
      tty.raw(min: 0, time: 0, intr: true) do
        keys.each do |key|
          value = query.call(key)
          return nil unless value
          values[key] = value
        end
      end
      values
    rescue IOError, SystemCallError, ArgumentError
      nil
    end
    original = snapshot.call
    unless original
      notify.call('终端不支持完整配色保存，或启动时收到其它输入；保留原配色并使用纯文本。')
      tty.close
      plain.call
      return
    end
    directory = Dir.mktmpdir('jobs-terminal-style-')
    recovery = File.join(directory, 'restore.sh')
    original_bytes = keys.map { |key| original.fetch(key).fetch(:raw) }.join
    recovery_source = "#!/bin/sh\n" \
      "[ -t 0 ] && [ \"$(tty)\" = '#{tty_name}' ] || { printf '请在原终端运行恢复入口。\\n' >&2; exit 1; }\n" \
      "printf '本操作会覆盖此终端当前配色。确认恢复脚本启动前的配色，请输入 YES：' >&2\n" \
      "IFS= read -r jobs_restore_choice\n[ \"$jobs_restore_choice\" = YES ] || exit 1\n" \
      "printf '%s\\033[0m' '#{original_bytes}' > /dev/tty\n"
    File.open(recovery, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
      file.binmode
      file.write(recovery_source.b)
    end
    notify.call("本次终端临时使用黑底白字；强退后恢复入口：sh \"#{recovery}\"")
    changed = false
    applied = nil
    # 比较仍生效的本轮颜色，只恢复未被用户另行修改的项。
    cleanup = lambda do
      current = applied && snapshot.call
      unless current
        notify.call("终端配色未能安全自动恢复；确认覆盖当前配色后可运行：sh \"#{recovery}\"")
        return false
      end
      conflicts = []
      restore_bytes = ''.b
      keys.each do |key|
        if current.fetch(key).fetch(:rgb) == applied.fetch(key).fetch(:rgb)
          restore_bytes << original.fetch(key).fetch(:raw)
        else
          conflicts << key
        end
      end
      tty.write(restore_bytes + "\e[0m".b)
      if conflicts.empty?
        File.unlink(recovery)
        Dir.rmdir(directory)
        true
      else
        notify.call("检测到运行期间的配色变更，已保留这些项：#{conflicts.join(' ')}")
        notify.call("确认要覆盖后续改色时才使用恢复入口：sh \"#{recovery}\"")
        false
      end
    rescue IOError, SystemCallError
      notify.call("终端配色未能安全自动恢复；确认覆盖当前配色后可运行：sh \"#{recovery}\"")
      false
    end
    child_pid = nil
    guardian = false
    interrupted = nil
    previous_signals = {}
    %w[INT TERM HUP].each do |name|
      previous_signals[name] = Signal.trap(name) do
        interrupted = name
        if child_pid && name != 'INT'
          begin
            Process.kill(name, child_pid)
          rescue Errno::ESRCH
          end
        end
      end
    end
    begin
      changed = true
      tty.write(targets.map { |key, color| "\e]#{key};##{color}\a" }.join + "\e[0m")
      applied = snapshot.call
      unless applied
        notify.call('无法核实本次临时配色，已停止启动业务。')
        raise SystemExit, 1
      end
      desired = targets.all? do |key, hex|
        rgb = hex.scan(/../).map { |component| component.to_i(16) * 257 }
        applied.fetch(key).fetch(:rgb).zip(rgb).all? { |actual, expected| (actual - expected).abs <= 255 }
      end
      unless desired
        notify.call('终端未接受本次配色，恢复后使用纯文本。')
        restored = cleanup.call
        changed = false
        raise SystemExit, 1 unless restored
        plain.call
        return
      end
      if interrupted
        raise SystemExit, 128 + Signal.list.fetch(interrupted)
      end
      if Thread.list.length > 1
        restored = cleanup.call
        changed = false
        raise SystemExit, 1 unless restored
        plain.call
        return
      end
      $stdout.flush
      $stderr.flush
      begin
        child_pid = Process.fork
      rescue NotImplementedError, SystemCallError
        restored = cleanup.call
        changed = false
        raise SystemExit, 1 unless restored
        plain.call
        return
      end
      unless child_pid
        changed = false
        ENV['JOBS_TERMINAL_STYLE_TTY'] = tty_name
        ENV['JOBS_TERMINAL_STYLE_OWNER'] = Process.ppid.to_s
        raise SystemExit, 128 + Signal.list.fetch(interrupted) if interrupted
        return
      end
      guardian = true
      result = nil
      loop do
        begin
          _, result = Process.wait2(child_pid)
          break
        rescue Interrupt, Errno::EINTR
        end
      end
      status_code = result.exitstatus || 128 + result.termsig
      %w[INT TERM HUP].each { |name| Signal.trap(name, 'IGNORE') }
      restored = cleanup.call
      changed = false
      status_code = 1 if !restored && status_code.zero?
      tty.close
      Process.exit!(status_code)
    ensure
      if changed
        %w[INT TERM HUP].each { |name| Signal.trap(name, 'IGNORE') }
        cleanup.call
      end
      previous_signals.each { |name, handler| Signal.trap(name, handler) } unless guardian
      tty.close unless tty.closed?
    end
  rescue IOError, SystemCallError, LoadError => error
    if guardian
      notify.call("终端保护监督进程异常：#{error.message}")
      Process.exit!(1)
    end
    raise SystemExit, 1 if changed
    notify.call("终端保护不可用，使用纯文本：#{error.message}")
    plain.call
  end
  jobs_terminal_style_bootstrap_v1

end
# JOBS_TERMINAL_STYLE_GUARD_V1_END

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
def add_reference(project, root, relative, folder = project.main_group)
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
test_root = File.expand_path('../../../../测试/前端/移动端/iOS', root)
test_group = project.main_group.groups.find { |group| group.name == 'Tests' || group.path == 'Tests' }
test_group ||= project.main_group.new_group('Tests')
test_group.name = 'Tests'
test_group.path = Pathname.new(test_root).relative_path_from(Pathname.new(root)).to_s
test_group.source_tree = 'SOURCE_ROOT'
Dir.glob(File.join(test_root, 'Data/**/*.swift')).sort.each do |file|
  relative = Pathname.new(file).relative_path_from(Pathname.new(test_root)).to_s
  reference = add_reference(project, test_root, relative, test_group)
  tests.source_build_phase.add_file_reference(reference, true)
end
['App/Resource/Assets.xcassets', 'App/Resource/JobsThemeResources.json', 'App/Resource/ui-l10n.json', 'App/Resource/PrivacyInfo.xcprivacy'].each do |relative|
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
