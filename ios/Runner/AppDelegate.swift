import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, AVSpeechSynthesizerDelegate {
  private let synthesizer = AVSpeechSynthesizer()
  private var ttsChannel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Setup TTS method channel
    let controller = window?.rootViewController as! FlutterViewController
    ttsChannel = FlutterMethodChannel(name: "com.annoyed.app/tts",
                                      binaryMessenger: controller.binaryMessenger)
    
    // Set delegate to receive completion callbacks
    synthesizer.delegate = self
    
    ttsChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      
      switch call.method {
      case "speak":
        if let args = call.arguments as? [String: Any],
           let text = args["text"] as? String {
          let utterance = AVSpeechUtterance(string: text)
          utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
          utterance.rate = 0.5
          self.synthesizer.speak(utterance)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT",
                            message: "Text argument is required",
                            details: nil))
        }
        
      case "stop":
        self.synthesizer.stopSpeaking(at: .immediate)
        result(nil)
        
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // AVSpeechSynthesizerDelegate method - called when speech finishes
  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    ttsChannel?.invokeMethod("onComplete", arguments: nil)
  }
}
