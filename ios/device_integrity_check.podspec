Pod::Spec.new do |s|
  s.name             = 'device_integrity_check'
  s.version          = '1.0.0'
  s.summary          = 'Root, jailbreak, emulator and developer-mode detection for Flutter.'
  s.description      = <<-DESC
Reports device-integrity signals separately, and reports which checks could not
run, so a failed probe is never mistaken for a clean device.
                       DESC
  s.homepage         = 'https://github.com/wiseminds/device_integrity_check'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Wisdom Ekeh'
  s.source           = { :path => '.' }
  s.source_files     = 'device_integrity_check/Sources/device_integrity_check/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'
  s.swift_version    = '5.0'

  # No third-party dependency: jailbreak detection is vendored in
  # Classes/JailbreakDetector.swift. See the comment at the top of that file.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
