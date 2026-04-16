Pod::Spec.new do |s|
  s.name             = 'vibegrowth_sdk'
  s.version          = '2.1.0'
  s.summary          = 'Vibe Growth SDK for Flutter - iOS platform bridge.'
  s.description      = 'Vibe Growth SDK Flutter plugin iOS implementation with attribution, user identity, and revenue tracking.'
  s.homepage         = 'https://vibegrowin.ai'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Vibe Growth' => 'dev@vibegrowin.ai' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.platform         = :ios, '14.0'
  s.swift_version    = '5.0'
  s.dependency 'Flutter'

  s.frameworks = 'StoreKit'
  s.weak_framework = 'AdServices'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
