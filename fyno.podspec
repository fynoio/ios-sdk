# fyno.podspec

Pod::Spec.new do |spec|
    spec.name         = "fyno"
    spec.version      = "1.0.0"
    spec.summary      = "A brief description of fyno."
  
    spec.description  = <<-DESC
      More detailed description of fyno.
    DESC
  
    spec.homepage     = "https://github.com/fynoio/ios-sdk"
    # Replace "yourusername" and adjust the URL accordingly.
  
    spec.license      = "MIT"
  
    spec.author             = { "Your Name" => "your@email.com" }
    # Replace "Your Name" and "your@email.com" with your information.
  
    spec.source       = { :git => "https://github.com/fynoio/ios-sdk.git", :tag => "#{spec.version}" }
    # Replace "yourusername" and adjust the URL accordingly.
  
    spec.swift_version = "5.7"
  
    spec.source_files = "Sources/**/*.swift"
    # Adjust the source file path accordingly.
  
    spec.ios.deployment_target = "12.0"
    # Adjust the deployment target as needed.
  
    spec.dependency "FMDB", "~> 2.7.5"
    spec.dependency 'SwiftyJSON', '~> 5.0'
    spec.dependency 'Firebase/Core', '~> 8.0'
    spec.dependency 'Firebase/Messaging', '~> 8.0'
  end
  
