Pod::Spec.new do |s|
  s.name             = 'TuyaHomeBridge'
  s.version          = '5.0.7'
  s.summary          = 'Objective-C bridge for Tuya home APIs used by uts-tuya-smart-sdk.'
  s.description      = 'Wraps ThingSmartHomeKit home APIs behind a simple NSDictionary callback bridge for UTS.'
  s.homepage         = 'https://github.com/ChenZhenChun/uts-tuya-smart-native-sdk'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'ChenZhenChun' => 'dev@example.com' }
  s.source           = { :git => 'https://github.com/ChenZhenChun/uts-tuya-smart-native-sdk.git', :tag => "v#{s.version}" }
  s.ios.deployment_target = '12.0'
  s.source_files = 'ios/Sources/TuyaHomeBridge/*.{h,m}'
  s.public_header_files = 'ios/Sources/TuyaHomeBridge/*.h'
end
