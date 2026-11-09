# Добавляет в Runner.xcodeproj расширение NetroTunnel (Packet Tunnel) и ядро LibXray.
# Запуск: ruby scripts/ios_add_tunnel.rb  (идемпотентно — повторный запуск ничего не ломает)
require 'xcodeproj'

ios = File.expand_path('../app/ios', __dir__)
proj = Xcodeproj::Project.open(File.join(ios, 'Runner.xcodeproj'))
app = proj.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless app

DEPLOY = '15.0'
APP_ID = 'pro.netro.netro'

# --- ядро: LibXray.xcframework (собирается в CI в app/ios/Frameworks) ---
fw_group = proj.main_group['Frameworks'] || proj.main_group.new_group('Frameworks', 'Frameworks')
fw_ref = fw_group.files.find { |f| f.path&.end_with?('LibXray.xcframework') } ||
         fw_group.new_reference('LibXray.xcframework')
fw_ref.source_tree = '<group>'
fw_ref.last_known_file_type = 'wrapper.xcframework'

ne_ref = proj.frameworks_group.files.find { |f| f.path&.include?('NetworkExtension.framework') } ||
         proj.frameworks_group.new_file('System/Library/Frameworks/NetworkExtension.framework', :sdk_root)

def link(target, ref)
  phase = target.frameworks_build_phase
  phase.add_file_reference(ref, true) unless phase.files_references.include?(ref)
end

link(app, fw_ref)
link(app, ne_ref)

# --- исходник моста в Runner ---
runner_group = proj.main_group['Runner']
unless runner_group.files.any? { |f| f.path == 'NetroCore.swift' }
  ref = runner_group.new_reference('NetroCore.swift')
  app.source_build_phase.add_file_reference(ref, true)
end
unless runner_group.files.any? { |f| f.path == 'Runner.entitlements' }
  runner_group.new_reference('Runner.entitlements')
end

app.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
  c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOY
  c.build_settings['FRAMEWORK_SEARCH_PATHS'] = ['$(inherited)', '$(PROJECT_DIR)/Frameworks']
end

# --- расширение NetroTunnel ---
ext = proj.targets.find { |t| t.name == 'NetroTunnel' }
unless ext
  ext = proj.new_target(:app_extension, 'NetroTunnel', :ios, DEPLOY, nil, :swift)
  g = proj.main_group['NetroTunnel'] || proj.main_group.new_group('NetroTunnel', 'NetroTunnel')
  src = g.new_reference('PacketTunnelProvider.swift')
  ext.source_build_phase.add_file_reference(src, true)
  g.new_reference('Info.plist')
  g.new_reference('NetroTunnel.entitlements')

  # встроить .appex в Runner.app/PlugIns
  embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.dst_subfolder_spec = '13' # PlugIns
  bf = embed.add_file_reference(ext.product_reference, true)
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  app.add_dependency(ext)
end

link(ext, fw_ref)
link(ext, ne_ref)

ext.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = "#{APP_ID}.tunnel"
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = 'NetroTunnel/Info.plist'
  s['CODE_SIGN_ENTITLEMENTS'] = 'NetroTunnel/NetroTunnel.entitlements'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOY
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['FRAMEWORK_SEARCH_PATHS'] = ['$(inherited)', '$(PROJECT_DIR)/Frameworks']
  s['SKIP_INSTALL'] = 'YES'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  s['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  s['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  s['ENABLE_BITCODE'] = 'NO'
  s['OTHER_LDFLAGS'] = ['$(inherited)', '-lresolv']
  # Flutter передаёт FLUTTER_BUILD_NAME/NUMBER через Generated.xcconfig Runner'а
  s.delete('ASSETCATALOG_COMPILER_APPICON_NAME')
end

# Своя конфигурация расширения: только версия из pubspec, без настроек Pods
tg = proj.main_group['NetroTunnel']
xc = tg.files.find { |f| f.path == 'NetroTunnel.xcconfig' } || tg.new_reference('NetroTunnel.xcconfig')
ext.build_configurations.each { |c| c.base_configuration_reference = xc }

proj.save
puts 'NetroTunnel ready'
