import Flutter
import UIKit
import AVFoundation

protocol Player {
    init(url: String, volume: Double)
    func play() -> Void
    func stop() -> Void
    func pause() -> Void
    func resume() -> Void
    func seek(position: Int) -> Void
    func volume(volume: Double) -> Void
    func position() -> Int64?
}

class LoopPlayer: Player {
    let player: AVQueuePlayer
    let playerLooper: AVPlayerLooper
    
    required init(url: String, volume: Double) {
        let asset = AVAsset(url: URL(fileURLWithPath: url ))
        
        let playerItem = AVPlayerItem(asset: asset)

        player = AVQueuePlayer(items: [playerItem])
        playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
        
        player.volume = Float(volume)
    }
    
    func play() {
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    func resume() {
        player.play()
    }
    
    func stop() {
        pause()
        seek(position: 0)
    }
    
    func seek(position: Int) {
        player.seek(to: CMTimeMakeWithSeconds(Float64(position / 1000), preferredTimescale: Int32(NSEC_PER_SEC)))
    }
    
    func volume(volume: Double) {
        player.volume = Float(volume)
    }
    
    func position() -> Int64? {
        guard let value = player.currentItem?.currentTime().value,
              let timescale = player.currentItem?.currentTime().timescale else {
            return nil
        }
        
        let positionInMillis = Int64((Float64(value) / Float64(timescale)) * 1000)
        
        NSLog("Ocarina::LoopPlayer => position (ms): \(positionInMillis)")
        return positionInMillis
    }
}

class SinglePlayer: Player {
    var player: AVAudioPlayer
    
    required init(url: String, volume: Double) {
        try! self.player = AVAudioPlayer(contentsOf: URL(fileURLWithPath: url ))
        self.player.volume = Float(volume)
        self.player.prepareToPlay()
    }
    
    func play() {
        seek(position: 0)
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    func resume() {
        player.play()
    }
    
    func stop() {
        pause()
    }
    
    func seek(position: Int) {
        player.currentTime = Float64(position) / 1000
    }
    
    func volume(volume: Double) {
        player.volume = Float(volume)
    }
    
    func position() -> Int64? {
        let positionInMillis = Int64(player.currentTime * 1000)
        
        NSLog("Ocarina::SinglePlayer => position (ms): \(positionInMillis)")
        return positionInMillis
    }
}

class PlayerDelegate {
    let loadDelegate: LoadDelegate
    let disposeDelegate: DisposeDelegate
    let playDelegate: PlayDelegate
    let pauseDelegate: PauseDelegate
    let resumeDelegate: ResumeDelegate
    let stopDelegate: StopDelegate
    let seekDelegate: SeekDelegate
    let volumeDelegate: VolumeDelegate
    let positionDelegate: PositionDelegate
    
    func load(_ id: Int, assetUrl: String, volume: Double, loop: Bool) {
        NSLog("Ocarina::PlayerDelegate => loading player \(id) from \(assetUrl) with delegate")
        let url: URL = URL(fileURLWithPath: assetUrl)
        let fileForPlayback: AVAudioFile?
        do {
            fileForPlayback = try AVAudioFile(forReading: url)
        } catch let error {
            NSLog("Cannot play music. Error opening file \(url) for reading \(error).")
            return
        }
        
        guard let file = fileForPlayback else {
            NSLog("Cannot play music. Cannot open file for reading \(url).")
            return
        }

        loadDelegate(id, file, loop, volume)
    }
    
    func dispose(_ id: Int) {
        disposeDelegate(id)
    }
    
    func play(_ id: Int) {
        NSLog("Ocarina::PlayerDelegate => playing \(id) with delegate")
        playDelegate(id)
    }

    func pause(_ id: Int) {
        NSLog("Ocarina::PlayerDelegate => pausing \(id) with delegate")
        pauseDelegate(id)
    }

    func resume(_ id: Int) {
        NSLog("Ocarina::PlayerDelegate => resuming \(id) with delegate")
        resumeDelegate(id)
    }

    func stop(_ id: Int) {
        NSLog("Ocarina::PlayerDelegate => stopping \(id) with delegate")
        stopDelegate(id)
    }

    func volume(_ id: Int, volume: Double) {
        NSLog("Ocarina::PlayerDelegate => setting volume for player \(id) to \(volume) with delegate")
        volumeDelegate(id, volume)
    }
    
    func seek(_ id: Int, positionInMillis: Int) {
        NSLog("Ocarina::PlayerDelegate => seeking for player \(id) to position \(positionInMillis) ms")
        seekDelegate(id, positionInMillis)
    }
    
    func position(_ id: Int) -> Int64 {
        return positionDelegate(id)
    }
    
    init(load: @escaping LoadDelegate, dispose: @escaping DisposeDelegate, play: @escaping PlayDelegate, pause: @escaping PauseDelegate, resume: @escaping ResumeDelegate, stop: @escaping StopDelegate, volume: @escaping VolumeDelegate, seek: @escaping SeekDelegate, position: @escaping PositionDelegate) {
        loadDelegate = load
        disposeDelegate = dispose
        playDelegate = play
        pauseDelegate = pause
        resumeDelegate = resume
        stopDelegate = stop
        volumeDelegate = volume
        seekDelegate = seek
        positionDelegate = position
    }
}

public typealias LoadDelegate = (_ id: Int, _ file: AVAudioFile, _ loop: Bool, _ volume: Double) -> Void
public typealias DisposeDelegate = (_ id: Int) -> Void
public typealias PlayDelegate = (_ id: Int) -> Void
public typealias PauseDelegate = (_ id: Int) -> Void
public typealias ResumeDelegate = (_ id: Int) -> Void
public typealias StopDelegate = (_ id: Int) -> Void
public typealias VolumeDelegate = (_ id: Int, _ volume: Double) -> Void
public typealias SeekDelegate = (_ id: Int, _ positionInMillis: Int) -> Void
public typealias PositionDelegate = (_ id: Int) -> Int64

public class SwiftOcarinaPlugin: NSObject, FlutterPlugin {
    static var players = [Int: Player]()
    static var id: Int = 0;
    static var delegate: PlayerDelegate?
    var registrar: FlutterPluginRegistrar? = nil
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "ocarina", binaryMessenger: registrar.messenger())
        let instance = SwiftOcarinaPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        instance.registrar = registrar
    }

    public static func useDelegate(load: @escaping LoadDelegate, dispose: @escaping DisposeDelegate, play: @escaping PlayDelegate, pause: @escaping PauseDelegate, resume: @escaping ResumeDelegate, stop: @escaping StopDelegate, volume: @escaping VolumeDelegate, seek: @escaping SeekDelegate, position: @escaping PositionDelegate) {
        delegate = PlayerDelegate(load: load, dispose: dispose, play: play, pause: pause, resume: resume, stop: stop, volume: volume, seek: seek, position: position)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if (call.method == "load") {
            load(call, result: result)
        } else if (call.method == "dispose") {
            dispose(call, result: result)
        } else if (call.method == "play") {
            play(call, result: result)
        } else if (call.method == "pause") {
            pause(call, result: result)
        } else if (call.method == "stop") {
            stop(call, result: result)
        } else if (call.method == "volume") {
            volume(call, result: result)
        } else if (call.method == "resume") {
            resume(call, result: result)
        } else if (call.method == "seek") {
            seek(call, result: result)
        } else if (call.method == "position") {
            position(call, result: result)
        }
    }
    
    func load(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments else {
            return;
        }
        
        if let myArgs = args as? [String: Any],
            let url: String = myArgs["url"] as? String,
            let volume: Double = myArgs["volume"] as? Double,
            let isAsset: Bool = myArgs["isAsset"] as? Bool,
            let loop: Bool = myArgs["loop"] as? Bool {
            
            var assetUrl: String
            if (isAsset) {
                let key: String?
                if let package: String = myArgs["package"] as? String {
                 key = registrar?.lookupKey(forAsset: url, fromPackage: package)
                } else {
                 key = registrar?.lookupKey(forAsset: url)
                }

                if let url = Bundle.main.path(forResource: key, ofType: nil) {
                    assetUrl = url
                } else {
                    return result(FlutterError(code: "ASSET_URL_NOT_FOUND", message: "key: " + (key ?? ""), details: nil))
                }
            } else {
                assetUrl = url
            }
            
            let id = SwiftOcarinaPlugin.id
            if let delegate = SwiftOcarinaPlugin.delegate {
                delegate.load(id, assetUrl: assetUrl, volume: volume, loop: loop)
            } else if (loop) {
                SwiftOcarinaPlugin.players[id] = LoopPlayer(url: assetUrl, volume: volume)
            } else {
                SwiftOcarinaPlugin.players[id] = SinglePlayer(url: assetUrl, volume: volume)
            }
            
            SwiftOcarinaPlugin.id = SwiftOcarinaPlugin.id + 1
            
            result(id)
        }
    }
    
    func dispose(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments else {
            return;
        }
        
        if let myArgs = args as? [String: Any],
            let playerId: Int = myArgs["playerId"] as? Int {
            
            if let delegate = SwiftOcarinaPlugin.delegate {
                delegate.dispose(playerId)
                result(0)
            } else {
                let player = SwiftOcarinaPlugin.players[playerId]
                player?.stop()
                SwiftOcarinaPlugin.players[playerId] = nil
                result(0)
            }
        }
    }

    func play(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments else {
            return;
        }
        
        if let myArgs = args as? [String: Any],
            let playerId: Int = myArgs["playerId"] as? Int {
            
            if let delegate = SwiftOcarinaPlugin.delegate {
                delegate.play(playerId)
            } else {
                let player = SwiftOcarinaPlugin.players[playerId]
                player?.play()
            }
            result(0)
        }
    }
    
    func pause(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments else {
            return;
        }
        
        if let myArgs = args as? [String: Any],
            let playerId: Int = myArgs["playerId"] as? Int {
         
            if let delegate = SwiftOcarinaPlugin.delegate {
                delegate.pause(playerId)
            } else {
                let player = SwiftOcarinaPlugin.players[playerId]
                player?.pause()
            }
            result(0)
        }
    }
    
    func stop(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments else {
            return;
        }
        
        if let myArgs = args as? [String: Any],
            let playerId: Int = myArgs["playerId"] as? Int {

            if let delegate = SwiftOcarinaPlugin.delegate {
                delegate.stop(playerId)
            } else {
                let player = SwiftOcarinaPlugin.players[playerId]
                player?.stop()
            }
            result(0)
        }
    }
    
    func volume(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments else {
            return;
        }
        
        if let myArgs = args as? [String: Any],
            let playerId: Int = myArgs["playerId"] as? Int,
            let volume: Double = myArgs["volume"] as? Double {
            
            if let delegate = SwiftOcarinaPlugin.delegate {
                delegate.volume(playerId, volume: volume)
            } else {
                let player = SwiftOcarinaPlugin.players[playerId]
                player?.volume(volume: volume)
            }
            result(0)
        }
    }
    
    func resume(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments else {
            return;
        }
        
        if let myArgs = args as? [String: Any],
            let playerId: Int = myArgs["playerId"] as? Int {
            
            if let delegate = SwiftOcarinaPlugin.delegate {
                delegate.resume(playerId)
            } else {
                let player = SwiftOcarinaPlugin.players[playerId]
                player?.resume()
            }
            result(0)
        }
    }
    
    func seek(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments else {
            return;
        }
        
        if let myArgs = args as? [String: Any],
            let playerId: Int = myArgs["playerId"] as? Int,
            let positionInMillis: Int = myArgs["position"] as? Int {
            
            if let delegate = SwiftOcarinaPlugin.delegate {
                delegate.seek(playerId, positionInMillis: positionInMillis)
                result(0)
            } else {
                let player = SwiftOcarinaPlugin.players[playerId]
                player?.seek(position: positionInMillis)
                result(0)
            }
        }
    }

    func position(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments else {
            return;
        }
        
        if let myArgs = args as? [String: Any],
            let playerId: Int = myArgs["playerId"] as? Int {
            
            if let delegate = SwiftOcarinaPlugin.delegate {
                result(delegate.position(playerId))
            } else {
                guard let player = SwiftOcarinaPlugin.players[playerId] else {
                    result(nil)
                    return
                }

                result(player.position())
            }
        }
    }
}
