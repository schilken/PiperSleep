import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import 'dart:convert';
import 'dart:developer' show log;
import 'dart:math' show Random;

Future<List<String>> listAssetFiles(String path) async {
  final manifestContent = await rootBundle.loadString('AssetManifest.json');
  final Map<String, dynamic> manifestMap = json.decode(manifestContent);
  final assetPaths =
      manifestMap.keys.where((String key) => key.startsWith(path)).toList();
  return assetPaths;
}

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool isPlaying = false;
  bool isShuffleEnabled = true; // Add shuffle state
  int playInterval = 5; // Interval in seconds
  int stopTimeout = 10; // Timeout in minutes
  Timer? stopTimer; // Stop playing after timeout
  Timer? playTimer; // Timer to play periodically
  AudioPlayer player = AudioPlayer();
  List<String> assetFiles = [];

  @override
  void initState() {
    super.initState();
    loadAssets();
    player.audioCache = AudioCache(prefix: ''); // prefix is in the path
  }

  Future<void> loadAssets() async {
    assetFiles = await listAssetFiles('assets/audio/');
  }

  // Stop audio and cancel timers
  void stopPlaying() {
    log('Stopping playback', name: 'MainApp');
    stopTimer?.cancel();
    playTimer?.cancel();
    player.stop();

    setState(() {
      isPlaying = false;
    });
  }

  // Play audio and set timers
  void startPlaying() {
    setState(() {
      isPlaying = true;
    });

    log('Invoking playback: $isShuffleEnabled, $playInterval', name: 'MainApp');

    // Stop after specified minutes
    stopTimer = Timer(Duration(minutes: stopTimeout), stopPlaying);

    int nextAsset = 0;
    playTimer = Timer.periodic(Duration(seconds: playInterval), (timer) async {
      if (isShuffleEnabled) {
        log('Shuffle play', name: 'MainApp');
        nextAsset = Random().nextInt(assetFiles.length);
      } else {
        if (++nextAsset >= assetFiles.length) nextAsset = 0;
      }

      log('Playing asset: $nextAsset', name: 'MainApp');
      await player.play(AssetSource(assetFiles[nextAsset]));
    });
  }

  @override
  void dispose() {
    log('Disposing', name: 'MainApp');
    stopTimer?.cancel();
    playTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system, // Use system theme mode
      home: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 300, // maximum width for the content
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IgnorePointer(
                    ignoring: isPlaying,
                    child: AnimatedOpacity(
                      opacity: isPlaying ? 0.5 : 1.0,
                      duration: Duration(milliseconds: 3000),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Shuffle'),
                              Switch(
                                value: isShuffleEnabled,
                                onChanged: (bool value) {
                                  setState(() {
                                    isShuffleEnabled = value;
                                  });
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 35), // Add space between elements
                          Text('Stop playing after: $stopTimeout minute(s)'),
                          Slider(
                            value: stopTimeout.toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: stopTimeout.toString(),
                            onChanged: (double value) {
                              setState(() {
                                stopTimeout = value.round();
                              });
                            },
                          ),
                          SizedBox(height: 35), // Add space between elements
                          Text('Play word every: $playInterval seconds'),
                          Slider(
                            value: playInterval.toDouble(),
                            min: 2,
                            max: 15,
                            divisions: 13,
                            label: playInterval.toString(),
                            onChanged: (double value) {
                              setState(() {
                                playInterval = value.round();
                              });
                            },
                          ),
                          SizedBox(height: 35), // Add space between elements
                        ],
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isPlaying ? stopPlaying : startPlaying,
                    child: Text(
                      isPlaying ? 'Stop' : 'Start Playing',
                      style: TextStyle(
                          fontWeight:
                              isPlaying ? FontWeight.bold : FontWeight.normal),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
