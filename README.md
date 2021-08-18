# Ocarina

Ocarina is a simple and easy to use audio package for Flutter. Its goal is to support audio play from local file (from assets, or filesystem), And to support it across all platforms that Flutter runs.

Right now, __we only support mobile (Android and iOS)__ and will eventually supporting Web and Desktop (Linux, MacOS and Windows).

## How to use

Using a file on your assets

```dart
final player = OcarinaPlayer(
  asset: 'assets/Loop-Menu.wav',
  package: 'my_package_name',
  loop: true,
  volume: 0.8,
);

await player.load();
```

Using a file on the device filesystem

```dart
final player = OcarinaPlayer(
  filePath: '/SomeWhere/On/The/Device/Loop-Menu.wav',
  loop: true,
  volume: 0.8,
);

await player.load();
```

## Docs 

List of all available methods on the player instance

`play`

Starts playing

`pause`

Pauses playback

`resume`

Resume when playback if it was previously paused

`stop`

Stops the playback, it can be started again by calling `play` again.

`seek(Duration)`

Moves the playback postion to the passed `Duration`

`position`

Retrieves playback position in milliseconds.

`updateVolume(double)`

Updates the volume, must be a value between 0 and 1

`dispose`

Clears the loaded resources in memory, to use the instance again a subsequent call on the `load` method is required

## iOS Delegation

This feature was developed in concert with the development of the `AVAudioEngineDevice` in [`twilio_programmable_video`](https://pub.dev/packages/twilio_programmable_video) version `0.10.0` to address the issue in iOS in which [the operating system gives priority to the `VoiceProcessingIO` Audio Unit](https://developer.apple.com/forums/thread/22133), causing output volume of audio files from `ocarina` to be significantly diminished when used while a call is underway. While this was the reason for introducing this feature to `ocarina`, it was designed to be agnostic to the nature of the delegate. It is strongly advised that if you are writing your own delegate for iOS, that you seek to mirror the behaviour of `ocarina` itself as much as is possible so as to reduce the possibility of inconsistent behaviour across platforms.

If you found your way here because `ocarina` was recommended by [`twilio_programmable_video`](https://pub.dev/packages/twilio_programmable_video), the following modification to your `AppDelegate` will setup the `AVAudioEngineDevice` as the delegate for `ocarina`:

```swift
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let audioDevice = AVAudioEngineDevice.getInstance()
    SwiftTwilioProgrammableVideoPlugin.setCustomAudioDevice(
        audioDevice,
        onConnected: audioDevice.onConnected,
        onDisconnected: audioDevice.onDisconnected)
    SwiftOcarinaPlugin.useDelegate(
        load: audioDevice.addMusicNode,
        dispose: audioDevice.disposeMusicNode,
        play: audioDevice.playMusic,
        pause: audioDevice.pauseMusic,
        resume: audioDevice.resumeMusic,
        stop: audioDevice.stopMusic,
        volume: audioDevice.setMusicVolume,
        seek: audioDevice.seekPosition,
        position: audioDevice.getPosition
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
```

## Android Audio Player State Listeners

This feature was also developed in concert with the ongoing development of the audio system for [`twilio_programmable_video`](https://pub.dev/packages/twilio_programmable_video), though it was designed to be agnostic to what other plugins you are using. As such, you can certainly add custom listeners via this mechanism to receive the same notifications. The only requirement is that they have the following signature:

```kotlin
(url: String, isPlaying: Boolean) -> Unit
```

If you wish to use this feature with [`twilio_programmable_video`](https://pub.dev/packages/twilio_programmable_video), simply add the following to your `MainActivity.kt`.

The benefit of using this feature with the[`twilio_programmable_video`](https://pub.dev/packages/twilio_programmable_video) is that it will enable that plugin to update the [Audio Focus](https://developer.android.com/guide/topics/media-apps/audio-focus) and usage of Bluetooth Sco based upon whether there are active audio players, in addition to an active call.

```kotlin
    private lateinit var PACKAGE_ID: String

    @RequiresApi(Build.VERSION_CODES.O)
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PACKAGE_ID = applicationContext.packageName
        OcarinaPlugin.addListener(PACKAGE_ID, TwilioProgrammableVideoPlugin.getAudioPlayerEventListener());
    }

    override fun cleanUpFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        OcarinaPlugin.removeListener(PACKAGE_ID)
    }
```