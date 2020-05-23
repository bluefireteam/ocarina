import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart';

import 'package:ocarina/ocarina.dart';

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
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

const staticFileUrl = 'https://luan.xyz/files/audio/ambient_c_motion.mp3';

class _MyHomePageState extends State<MyHomePage> {
  OcarinaPlayer _player;
  String _localFilePath;
  bool _loop = true;
  bool _fetchingFile = false;

  Future _loadFile() async {
    final bytes = await readBytes(staticFileUrl);
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
                player: _player,
                onBack: () {
                  setState(() {
                    _localFilePath = null;
                    _fetchingFile = false;
                    _player = null;
                  });
                })
            : Column(
                children: [
                  RaisedButton(
                      child: Text(_loop ? "Loop mode" : "Single play mode"),
                      onPressed: () async {
                        setState(() {
                          _loop = !_loop;
                        });
                      }),
                  RaisedButton(
                      child: Text("Play asset audio"),
                      onPressed: () async {
                        final player = OcarinaPlayer(
                            asset: 'assets/Loop-Menu.wav', loop: _loop);

                        setState(() {
                          _player = player;
                        });
                      }),
                  RaisedButton(
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

  PlayerWidget({this.player, this.onBack});

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
                return Text("Error loading player");
              }
              return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    RaisedButton(
                        child: Text("Play"),
                        onPressed: () async {
                          await player.play();
                        }),
                    RaisedButton(
                        child: Text("Stop"),
                        onPressed: () {
                          player.stop();
                        }),
                    RaisedButton(
                        child: Text("Pause"),
                        onPressed: () {
                          player.pause();
                        }),
                    RaisedButton(
                        child: Text("Resume"),
                        onPressed: () {
                          player.resume();
                        }),
                    RaisedButton(
                        child: Text("Seek to 5 secs"),
                        onPressed: () {
                          player.seek(Duration(seconds: 5));
                        }),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text("Volume"),
                      RaisedButton(
                          child: Text("0.2"),
                          onPressed: () {
                            player.updateVolume(0.2);
                          }),
                      RaisedButton(
                          child: Text("0.5"),
                          onPressed: () {
                            player.updateVolume(0.5);
                          }),
                      RaisedButton(
                          child: Text("1.0"),
                          onPressed: () {
                            player.updateVolume(1.0);
                          }),
                    ]),
                    RaisedButton(
                        child: Text("Dispose"),
                        onPressed: () async {
                          await player.dispose();
                        }),
                    RaisedButton(
                        child: Text("Go Back"),
                        onPressed: () async {
                          onBack?.call();
                        }),
                  ]);
          }
          return Container();
        });
  }
}
