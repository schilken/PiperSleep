import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeService();
  runApp(const MainApp());
}

void initializeService() {
  FlutterBackgroundService().configure(
      iosConfiguration: IosConfiguration(),
      androidConfiguration: AndroidConfiguration(
        autoStart: false,
        isForegroundMode: true,
        foregroundServiceTypes: [AndroidForegroundType.mediaPlayback],
        initialNotificationTitle: 'PiperSleep',
        initialNotificationContent: 'Playing words to help you sleep',
        onStart: onStart,
      ));
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  log('onStart', name: 'PiperSleepService');

  final player = AudioPlayer();
  // we already have prefix in the path
  player.audioCache = AudioCache(prefix: '');

  final assetFiles = await listAssetFiles('assets/audio/');
  Timer? playTimer; // Timer to play periodically

  log('Found $assetFiles.length assets', name: 'PiperSleepService');

  // Start playing audio and timer
  service.on('playAudio').listen((event) async {
    log('Starting playback', name: 'PiperSleepService');

    bool isShuffleEnabled = event?['isShuffleEnabled'];
    int playInterval = event?['playInterval'];
    int nextAsset = 0;

    playTimer?.cancel();
    playTimer = Timer.periodic(Duration(seconds: playInterval), (timer) async {
      if (isShuffleEnabled) {
        log('Shuffle play', name: 'PiperSleepService');
        nextAsset = Random().nextInt(assetFiles.length);
      } else {
        if (++nextAsset >= assetFiles.length) nextAsset = 0;
      }

      log('Playing asset: $nextAsset', name: 'PiperSleepService');
      await player.play(AssetSource(assetFiles[nextAsset]));
    });
  });

  // Stop playback logic
  service.on('stopAudio').listen((event) async {
    log('Stopping playback', name: 'PiperSleepService');
    await player.stop();
    playTimer?.cancel();
    service.stopSelf();
  });
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

  @override
  void initState() {
    super.initState();
  }

  void stopPlaying() {
    log('Stopping playback', name: 'MainApp');
    stopTimer?.cancel();
    FlutterBackgroundService().invoke('stopAudio');

    setState(() {
      isPlaying = false;
    });
  }

  // Play audio and set timers
  void startPlaying() async {
    setState(() {
      isPlaying = true;
    });

    bool isServiceRunning = await FlutterBackgroundService().isRunning();
    if (!isServiceRunning) {
      log('Service is not running, starting', name: 'PiperSleepService');
      await Future.wait([
        FlutterBackgroundService().startService(),
        Future.delayed(Duration(seconds: 2))
      ]);
    }

    log('Invoking playback: $isShuffleEnabled, $playInterval', name: 'MainApp');

    // Stop after specified minutes
    stopTimer = Timer(Duration(minutes: stopTimeout), stopPlaying);

    FlutterBackgroundService().invoke('playAudio',
        {'isShuffleEnabled': isShuffleEnabled, 'playInterval': playInterval});
  }

  @override
  void dispose() {
    log('Disposing', name: 'MainApp');
    stopTimer?.cancel();
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
