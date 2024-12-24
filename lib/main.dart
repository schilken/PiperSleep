import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:developer' show log;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeService();
  runApp(const MainApp());
}

void initializeService() {
  FlutterBackgroundService().configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      autoStart: true,
    ),
  );
}

void onStart(ServiceInstance service) async {
  final player = AudioPlayer();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
      log('Service set as foreground', name: 'onStart');
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
      log('Service set as background', name: 'onStart');
    });
  }

  service.on('playAudio').listen((event) async {
    log('Playing audio called', name: 'onStart');

    if (player.state == PlayerState.playing) {
      await player.stop();
    }
    
    await player.play(AssetSource("test.mp3"));

    player.onPlayerComplete.listen((event) {
      service.invoke('audioCompleted');
      log('Audio completed', name: 'onStart');
    });
  });

  service.on('stopAudio').listen((event) async {
    await player.stop();
    log('Audio stopped', name: 'onStart');
  });
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool isPlaying = false;
  int stopTimeout = 1; // Timeout in minutes
  int playInterval = 10; // Interval in seconds
  Timer? _stopTimer;
  Timer? _playTimer;

  @override
  void initState() {
    super.initState();
    FlutterBackgroundService().on('audioCompleted').listen((event) {
      setState(() {
        isPlaying = false;
      });
    });
  }

  void _playAudio() {
    FlutterBackgroundService().invoke('playAudio');
    setState(() {
      isPlaying = true;
    });
    _stopTimer = Timer(Duration(minutes: stopTimeout), _stopAudio); // Stop after specified minutes
    _playTimer = Timer.periodic(Duration(seconds: playInterval), (timer) {
      log('Running periodically', name: 'PlayTimer');
      FlutterBackgroundService().invoke('playAudio');
    });
  }

  void _stopAudio() {
    FlutterBackgroundService().invoke('stopAudio');
    setState(() {
      isPlaying = false;
    });
    _stopTimer?.cancel();
    _playTimer?.cancel();
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _playTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 300, // Set your desired maximum width here
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 35,
              children: [
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
                Text('Stop playing af: $stopTimeout minutes'),
                Slider(
                  value: playInterval.toDouble(),
                  min: 1,
                  max: 60,
                  divisions: 59,
                  label: playInterval.toString(),
                  onChanged: (double value) {
                    setState(() {
                      playInterval = value.round();
                    });
                  },
                ),
                Text('Play interval: $playInterval seconds'),
                ElevatedButton(
                  onPressed: isPlaying ? _stopAudio : _playAudio,
                  child: Text(
                    isPlaying ? 'Stop' : 'Start Playing',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
