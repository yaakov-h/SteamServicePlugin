Pod::Spec.new do |s|
  s.name         = 'SKSteamKit'
  s.version      = '0.1.6'
  s.summary      = 'SteamKit port for Objective-C'
  s.description  = <<-DESC
	Objective-C library for connecting to the Steam network. Based on SteamKit/SteamRE by OpenSteamWorks.
                    DESC
  s.homepage     = 'https://github.com/yaakov-h/SKSteamKit'

  s.author       = 'Yaakov'
  s.source       = { :git => 'https://github.com/yaakov-h/SKSteamKit.git' }

  s.platform     = :osx, '10.8'
  s.public_header_files = 'SteamKit/**/SK*.h', 'SKSteamKit.h'
  s.framework  = 'Foundation', 'UIKit', 'CoreGraphics'
  s.requires_arc = true
  
 s.subspec 'arc' do |a|
  a.source_files = 'SteamKit/Messages/SteamLanguage/**/*.{h,m}', 'SteamKit/Messages/**/_*.{h,m}', 'SteamKit/{Crypto,KeyValues,Networking,Steam3,Util}/**/*.{h,m}'
  a.requires_arc	= true
 end
 
 s.subspec 'nonarc' do |na|
  na.source_files = 'SteamKit/Messages/**/*.pb.{h,m}'
  na.requires_arc	= false
 end

 s.dependency 'ProtocolBuffers',	:podspec => 'https://raw.github.com/yaakov-h/SKSteamKit/master/podspecs/ProtocolBuffers.podspec'
 s.dependency 'CocoaAsyncSocket',	'~> 0.0.1'
 s.dependency 'CRBoilerplate',		:podspec => '/Users/yaakov/Development/SteamServicePlugin/CRBoilerplate.podspec'
 s.dependency 'zipzap',			:podspec => '/Users/yaakov/Development/SteamServicePlugin/zipzap.podspec'
end
