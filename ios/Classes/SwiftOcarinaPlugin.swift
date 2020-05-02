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
        player.currentTime = Float64(position / 1000)
    }
    
    func volume(volume: Double) {
        player.volume = Float(volume)
    }
}

public class SwiftOcarinaPlugin: NSObject, FlutterPlugin {
    static var players = [Int: Player]()
    static var id: Int = 0;
    var registrar: FlutterPluginRegistrar? = nil
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "ocarina", binaryMessenger: registrar.messenger())
        let instance = SwiftOcarinaPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        instance.registrar = registrar
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if (call.method == "load") {
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
                    let key = registrar?.lookupKey(forAsset: url)
                    assetUrl = Bundle.main.path(forResource: key, ofType: nil)!
                } else {
                    assetUrl = url
                }
                
                let id = SwiftOcarinaPlugin.id
                if (loop) {
                    SwiftOcarinaPlugin.players[id] = LoopPlayer(url: assetUrl, volume: volume)
                } else {
                    SwiftOcarinaPlugin.players[id] = SinglePlayer(url: assetUrl, volume: volume)
                }
                
                SwiftOcarinaPlugin.id = SwiftOcarinaPlugin.id + 1
                
                result(id)
            }
        } else if (call.method == "play") {
            guard let args = call.arguments else {
                return;
            }
            
            if let myArgs = args as? [String: Any],
                let playerId: Int = myArgs["playerId"] as? Int {
                
                let player = SwiftOcarinaPlugin.players[playerId]
                player?.play()
            }
        } else if (call.method == "pause") {
                   guard let args = call.arguments else {
                       return;
                   }
                   
                   if let myArgs = args as? [String: Any],
                       let playerId: Int = myArgs["playerId"] as? Int {
                       
                       let player = SwiftOcarinaPlugin.players[playerId]
                       player?.pause()
                   }
        } else if (call.method == "stop") {
            guard let args = call.arguments else {
                return;
            }
            
            if let myArgs = args as? [String: Any],
                let playerId: Int = myArgs["playerId"] as? Int {
                
                let player = SwiftOcarinaPlugin.players[playerId]
                player?.stop()
            }
            
        } else if (call.method == "volume") {
            guard let args = call.arguments else {
                return;
            }
            
            if let myArgs = args as? [String: Any],
                let playerId: Int = myArgs["playerId"] as? Int,
                let volume: Double = myArgs["volume"] as? Double {
                
                let player = SwiftOcarinaPlugin.players[playerId]
                player?.volume(volume: volume)
            }
        } else if (call.method == "resume") {
            guard let args = call.arguments else {
                return;
            }
            
            if let myArgs = args as? [String: Any],
                let playerId: Int = myArgs["playerId"] as? Int {
                
                let player = SwiftOcarinaPlugin.players[playerId]
                player?.resume()
            }
        } else if (call.method == "seek") {
            guard let args = call.arguments else {
                return;
            }
            
            if let myArgs = args as? [String: Any],
                let playerId: Int = myArgs["playerId"] as? Int,
                let positionInMillis: Int = myArgs["position"] as? Int {
                
                let player = SwiftOcarinaPlugin.players[playerId]
                player?.seek(position: positionInMillis)
            }
        }
    }
}
