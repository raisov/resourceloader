Pod::Spec.new do |s|
  s.name         = "ResourceLoader"
  s.version      = "0.1.0"
  s.summary      = "Swift library to asynchronously load resources identified by URL."
  s.description  = <<-DESC
  A much much longer description of MyFramework.
  A much much longer description of MyFramework.
  A much much longer description of MyFramework.
  A much much longer description of MyFramework.
  A much much longer description of MyFramework.
                   DESC
  s.homepage     = "https://github.com/raisov/ResourceLoader"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "Vladimir Raisov" => "raisov@gmail.com" }
  s.source       = { :git => 'https://github.com/raisov/resourceloader.git', :tag => s.version.to_s }
  s.source_files = "ResourceLoader/*.swift"

  s.swift_version = "4.0"
  s.ios.deployment_target = '10.0'
end