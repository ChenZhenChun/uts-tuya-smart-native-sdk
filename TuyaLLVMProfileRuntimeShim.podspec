Pod::Spec.new do |s|
  s.name             = 'TuyaLLVMProfileRuntimeShim'
  s.version          = '5.0.3'
  s.summary          = 'LLVM profile runtime symbol shim for Tuya iOS binaries.'
  s.description      = 'Provides the __llvm_profile_runtime symbol required by selected Tuya iOS binary objects.'
  s.homepage         = 'https://github.com/ChenZhenChun/uts-tuya-smart-native-sdk'
  s.license          = { :type => 'Commercial', :text => 'Copyright belongs to the respective SDK owners.' }
  s.author           = { 'ChenZhenChun' => '346891964@qq.com' }
  s.source           = {
    :git => 'https://github.com/ChenZhenChun/uts-tuya-smart-native-sdk.git',
    :tag => "v#{s.version}"
  }

  s.ios.deployment_target = '9.0'
  s.source_files = 'ios/Sources/LLVMProfileRuntimeShim.c'
end
