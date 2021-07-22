Pod::Spec.new do |spec|
    spec.name         = 'ThorchainFramework'
    spec.version      = '0.0.9'
    spec.swift_version = '5.3'
    spec.ios.deployment_target = "9.0"
    spec.osx.deployment_target = "10.14"
    spec.tvos.deployment_target = "12.0"
    spec.watchos.deployment_target = "5.0"
    spec.dependency 'BigInt', '~> 5.2'
    spec.license      = { :type => 'MIT', :file => 'LICENSE' }
    spec.summary      = 'Native Swift Thorchain client side logic'
    spec.homepage     = 'https://github.com/thorchain/thorchain-ios'
    spec.author       = 'Hildisvíni Óttar'
    spec.source       = { :git => 'https://github.com/thorchain/thorchain-ios.git', :tag => 'v' + String(spec.version) }
    spec.source_files = 'Sources/ThorchainFramework/*.swift'
    spec.social_media_url = 'https://twitter.com/thorchain_org'
    spec.documentation_url = 'https://github.com/thorchain/thorchain-ios'
end
