# fyno-push-ios.podspec

Pod::Spec.new do |spec|
    spec.name         = "fyno-push-ios"
    spec.version      = "3.4.0"
    spec.summary      = "Fyno's iOS SDK."
  
    spec.description  = <<-DESC
      Fyno's iOS SDK to support push notifications on iOS devices.
    DESC
  
    spec.homepage     = "https://github.com/fynoio/ios-sdk"
    # Replace "yourusername" and adjust the URL accordingly.
  
    spec.license      = "MIT"
  
    spec.author             = { "Viram Jain" => "viram@fyno.io" }
    # Replace "Your Name" and "your@email.com" with your information.
  
    spec.source       = { :git => "https://github.com/fynoio/ios-sdk.git", :tag => "#{spec.version}" }
    # Replace "yourusername" and adjust the URL accordingly.
  
    spec.swift_version = "5.7"
  
    spec.source_files = "Sources/**/*.swift"
    # Adjust the source file path accordingly.
  
    spec.ios.deployment_target = "13.0"
    # Adjust the deployment target as needed.
  
    spec.dependency "FMDB", "~> 2.7.5"
    spec.dependency 'SwiftyJSON', '~> 5.0'
    spec.dependency 'Firebase/Messaging', '11.4.0'

    spec.vendored_frameworks = "fyno.xcframework"
  end
  
