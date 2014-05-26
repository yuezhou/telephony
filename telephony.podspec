# Be sure to run `pod lib lint NAME.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = "telephony"
  s.version          = "0.1.0"
  s.summary          = "pjsip as telephony library."
#  s.description      = <<-DESC
#                       An optional longer description of telephony
#
#                       * Markdown format.
#                       * Don't worry about the indent, we strip it!
#                       DESC
  s.homepage         = "https://github.com/yuezhou/"
#  s.screenshots      = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "Yue Zhou" => "yue.zhou@savantsystems.com" }
  s.source           = { :git => "https://github.com/yuezhou/telephony.git", :tag => "0.1.0" }
#  s.social_media_url = 'https://twitter.com/EXAMPLE'

  # s.platform     = :ios, '5.0'
  # s.ios.deployment_target = '7.0'
  # s.osx.deployment_target = '10.7'
  s.requires_arc = true

#  s.source_files = 'telephony/Classes/Telephony/**/*.*'
#  s.header_dir = 'telephony/Classes/pjproject-2.2.1/pjsip/include/pjsua-lib'
  #s.resources = 'Assets/*.png'

   s.preserve_paths = 'telephony/Classes/pjproject-2.2.1/**/*.h'
   s.vendored_libraries = 'telephony/Classes/pjproject-2.2.1/libpjsip-universal-apple.a'
   s.libraries = 'pjsip-universal-apple'

#  s.ios.exclude_files = 'Classes/osx'
#  s.osx.exclude_files = 'Classes/ios'
#   s.public_header_files = 'telephony/Classes/pjproject-2.2.1/**/*.h'
  #s.frameworks = 'lib'
  # s.dependency 'JSONKit', '~> 1.4'
#  s.xcconfig = {'HEADER_SEARCH_PATHS' => '${PODS_ROOT}/telephony/telephony/Classes/pjproject-2.2.1/pjsip/include ${PODS_ROOT}/telephony/telephony/Classes/pjproject-2.2.1/pjsip/include/pjsua-lib ${PODS_ROOT}/telephony/telephony/Classes/pjproject-2.2.1/pjlib/include ${PODS_ROOT}/telephony/telephony/Classes/pjproject-2.2.1/pjlib-util/include ${PODS_ROOT}/telephony/telephony/Classes/pjproject-2.2.1/pjmedia/include ${PODS_ROOT}/telephony/telephony/Classes/pjproject-2.2.1/pjnath/include ${PODS_ROOT}/telephony/telephony/Classes/pjproject-2.2.1/third_party/include'}

end
