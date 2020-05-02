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

## Methods

List of all available methods on the player instance

 - `play`
 - `pause`
 - `resume`
 - `stop`
 - `seek(Duration)`
 - `updateVolume(double)` - Value between 0 and 1
