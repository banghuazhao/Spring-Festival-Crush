# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'Spring Festival Crush' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Spring Festival Crush
  pod 'Then'
  pod 'Localize-Swift', '~> 2.0'
  pod 'SwiftyButton'
  pod 'SnapKit', '~> 5.0.0'
  pod 'Google-Mobile-Ads-SDK'
  pod 'Hue'

  # Pods for Space Charge
  post_install do |installer|

      installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
          config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
        end
      end

      installer.pods_project.targets.each do |target|
          if target.name.start_with?("Pods")
              puts "Updating #{target.name} OTHER_LDFLAGS to OTHER_LDFLAGS[sdk=iphone*]"
              target.build_configurations.each do |config|
                  xcconfig_path = config.base_configuration_reference.real_path
                  xcconfig = File.read(xcconfig_path)
                  new_xcconfig = xcconfig.sub('OTHER_LDFLAGS =', 'OTHER_LDFLAGS[sdk=iphone*] =')
                  File.open(xcconfig_path, "w") { |file| file << new_xcconfig }
              end
          end
      end
  end

end
