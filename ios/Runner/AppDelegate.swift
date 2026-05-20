import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let mediaChannelName = "tanisma_app/media"
  private var recorder: AVAudioRecorder?
  private var recordingUrl: URL?
  private var player: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: mediaChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }

      switch call.method {
      case "startVoiceRecording":
        self.startVoiceRecording(result: result)
      case "stopVoiceRecording":
        self.stopVoiceRecording(result: result)
      case "playVoiceData":
        let args = call.arguments as? [String: Any]
        self.playVoiceData(dataUrl: args?["dataUrl"] as? String, result: result)
      case "stopVoicePlayback":
        self.stopVoicePlayback(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startVoiceRecording(result: @escaping FlutterResult) {
    let session = AVAudioSession.sharedInstance()

    session.requestRecordPermission { [weak self] granted in
      DispatchQueue.main.async {
        guard let self else { return }

        guard granted else {
          result(
            FlutterError(
              code: "record_permission_denied",
              message: "Mikrofon izni verilmedi.",
              details: nil
            )
          )
          return
        }

        do {
          try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
          try session.setActive(true)

          let fileName = "voice_\(Int(Date().timeIntervalSince1970 * 1000)).m4a"
          let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
          let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22050,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32000,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
          ]

          self.recorder?.stop()
          self.recorder = try AVAudioRecorder(url: url, settings: settings)
          self.recordingUrl = url
          self.recorder?.record()
          result(nil)
        } catch {
          self.cleanupRecording()
          result(
            FlutterError(
              code: "record_start_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }

  private func stopVoiceRecording(result: FlutterResult) {
    guard let recorder, let recordingUrl else {
      result(nil)
      return
    }

    do {
      recorder.stop()
      self.recorder = nil
      self.recordingUrl = nil

      let data = try Data(contentsOf: recordingUrl)
      try? FileManager.default.removeItem(at: recordingUrl)
      result("data:audio/mp4;base64,\(data.base64EncodedString())")
    } catch {
      cleanupRecording()
      result(
        FlutterError(
          code: "record_stop_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func playVoiceData(dataUrl: String?, result: FlutterResult) {
    guard let dataUrl, !dataUrl.isEmpty else {
      result(
        FlutterError(
          code: "empty_audio",
          message: "Ses kaydı bulunamadı.",
          details: nil
        )
      )
      return
    }

    let encoded = dataUrl.split(separator: ",", maxSplits: 1).last.map(String.init) ?? dataUrl

    guard let data = Data(base64Encoded: encoded) else {
      result(
        FlutterError(
          code: "invalid_audio",
          message: "Ses kaydı okunamadı.",
          details: nil
        )
      )
      return
    }

    do {
      player?.stop()
      player = try AVAudioPlayer(data: data)
      player?.prepareToPlay()
      player?.play()
      result(nil)
    } catch {
      player = nil
      result(
        FlutterError(
          code: "playback_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func stopVoicePlayback(result: FlutterResult) {
    player?.stop()
    player = nil
    result(nil)
  }

  private func cleanupRecording() {
    recorder?.stop()
    recorder = nil

    if let recordingUrl {
      try? FileManager.default.removeItem(at: recordingUrl)
    }
    recordingUrl = nil
  }
}
