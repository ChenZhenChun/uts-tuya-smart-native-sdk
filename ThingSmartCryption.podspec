Pod::Spec.new do |s|
  s.name             = 'ThingSmartCryption'
  s.version          = '5.0.3'
  s.summary          = 'Tuya app-specific security SDK.'
  s.description      = 'App-specific Tuya Smart security SDK binary dependency used by uts-tuya-smart-sdk.'
  s.homepage         = 'https://github.com/ChenZhenChun/uts-tuya-smart-native-sdk'
  s.license          = { :type => 'Commercial', :text => 'Copyright belongs to the respective SDK owners.' }
  s.author           = { 'ChenZhenChun' => '346891964@qq.com' }
  s.source           = {
    :git => 'https://github.com/ChenZhenChun/uts-tuya-smart-native-sdk.git',
    :tag => "v#{s.version}"
  }

  s.ios.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'
  s.requires_arc     = true
  s.ios.source_files = 'ios/Frameworks/ThingSmartCryption.xcframework/ios*simulator/ThingSmartCryption.framework/Headers/*'
  s.watchos.source_files = 'ios/Frameworks/ThingSmartCryption.xcframework/watchos*simulator/ThingSmartCryption.framework/Headers/*'
  s.vendored_frameworks = 'ios/Frameworks/ThingSmartCryption.xcframework'
  s.resources        = [
    'ios/Frameworks/ThingSmartCryption.xcframework/ios*simulator/**/*.bundle',
    'ios/Frameworks/ThingSmartCryption.xcframework/ios*simulator/**/t_cdc.tcfg'
  ]

  s.user_target_xcconfig = {
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES'
  }
  s.pod_target_xcconfig = {
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
  }
end
