# Ocarina

Ocarina is a simple and easy to usade audio package for Flutter. Its goal is to support audio play from local file (from assets, or filesystem), And to support it across all platforms that Flutter runs.

Right now, __we only support mobile (Android and iOS)__ and will eventually supporting Web and Desktop (Linux, MacOS and Windows).

## How to use

Using a file on your assets

```dart
final player = OcarinaPlayer(
  asset: 'assets/Loop-Menu.wav',
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

`updateVolume(double)`

Updates the volume, must be a value between 0 and 1

`dispose`

Clears the loaded resources in memory, to use the instance again a subsequent call on the `load` method is required
