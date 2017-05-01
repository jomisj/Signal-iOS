platform :ios, '9.0'
source 'https://github.com/CocoaPods/Specs.git'

target 'Signal' do
    pod 'SocketRocket',               :git => 'https://github.com/facebook/SocketRocket.git'
    pod 'AxolotlKit',                 git: 'https://github.com/WhisperSystems/SignalProtocolKit.git'
    #pod 'AxolotlKit',                 path: '../SignalProtocolKit'
    pod 'SignalServiceKit',           git: 'https://github.com/WhisperSystems/SignalServiceKit.git', branch: 'mkirk/delay-contact-access'
    #pod 'SignalServiceKit',           path: '../SignalServiceKit'
    pod 'OpenSSL'
    pod 'SCWaveformView',             '~> 1.0'
    pod 'JSQMessagesViewController',  git: 'https://github.com/WhisperSystems/JSQMessagesViewController.git', branch: 'mkirk/position-edit-menu'
    #pod 'JSQMessagesViewController'   path: '../JSQMessagesViewController'
    pod 'PureLayout'
    target 'SignalTests' do
        inherit! :search_paths
    end
end
