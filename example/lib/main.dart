import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:ocarina/ocarina.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Ocarina Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({required this.title});

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

const staticFileUrl = 'https://luan.xyz/files/audio/ambient_c_motion.mp3';

class _MyHomePageState extends State<MyHomePage> {
  OcarinaPlayer? _player;
  String? _localFilePath;
  bool _loop = true;
  bool _fetchingFile = false;

  Future _loadFile() async {
    final bytes = await readBytes(Uri.parse(staticFileUrl));
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/audio.mp3');

    await file.writeAsBytes(bytes);
    if (await file.exists()) {
      setState(() {
        _localFilePath = file.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: (_player != null
            ? PlayerWidget(
                player: _player!,
                onBack: () {
                  setState(() {
                    _localFilePath = null;
                    _fetchingFile = false;
                    _player = null;
                  });
                })
            : Column(
                children: [
                  ElevatedButton(
                      child: Text(_loop ? "Loop mode" : "Single play mode"),
                      onPressed: () async {
                        setState(() {
                          _loop = !_loop;
                        });
                      }),
                  ElevatedButton(
                      child: Text("Play asset audio"),
                      onPressed: () async {
                        final player = OcarinaPlayer(
                            asset: 'assets/Loop-Menu.wav', loop: _loop);

                        setState(() {
                          _player = player;
                        });
                      }),
                  ElevatedButton(
                      child: Text(_fetchingFile
                          ? "Fetching file..."
                          : "Download file to Device, and play it"),
                      onPressed: () async {
                        if (_fetchingFile) return;
                        setState(() {
                          _fetchingFile = true;
                        });
                        await _loadFile();

                        final player = OcarinaPlayer(filePath: _localFilePath);
                        await player.load();

                        setState(() {
                          _player = player;
                        });
                      })
                ],
              )),
      ),
    );
  }
}

class PlayerWidget extends StatelessWidget {
  final OcarinaPlayer player;
  final VoidCallback onBack;

  PlayerWidget({required this.player, required this.onBack});

  @override
  Widget build(_) {
    return FutureBuilder(
        future: player.load(),
        builder: (ctx, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
            case ConnectionState.none:
            case ConnectionState.active:
              return Text("Loading player");
            case ConnectionState.done:
              if (snapshot.hasError) {
                return Column(
                  children: [
                    Text("Error loading player"),
                    ElevatedButton(
                      child: Text("Go Back"),
                      onPressed: onBack.call,
                    ),
                  ],
                );
              }
              return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    ElevatedButton(
                        child: Text("Play"),
                        onPressed: () async {
                          await player.play();
                        }),
                    ElevatedButton(
                        child: Text("Stop"),
                        onPressed: () async {
                          await player.stop();
                        }),
                    ElevatedButton(
                        child: Text("Pause"),
                        onPressed: () async {
                          await player.pause();
                        }),
                    ElevatedButton(
                        child: Text("Resume"),
                        onPressed: () async {
                          await player.resume();
                        }),
                    ElevatedButton(
                        child: Text("Seek to 5 secs"),
                        onPressed: () async {
                          await player.seek(Duration(seconds: 5));
                        }),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text("Volume"),
                      ElevatedButton(
                          child: Text("0.2"),
                          onPressed: () async {
                            await player.updateVolume(0.2);
                          }),
                      ElevatedButton(
                          child: Text("0.5"),
                          onPressed: () async {
                            await player.updateVolume(0.5);
                          }),
                      ElevatedButton(
                          child: Text("1.0"),
                          onPressed: () async {
                            await player.updateVolume(1.0);
                          }),
                    ]),
                    ElevatedButton(
                        child: Text("Dispose"),
                        onPressed: () async {
                          await player.dispose();
                        }),
                    ElevatedButton(
                      child: Text("Go Back"),
                      onPressed: onBack.call,
                    ),
                  ]);
          }
        });
  }
}
