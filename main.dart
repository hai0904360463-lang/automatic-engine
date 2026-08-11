import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GpsSpeedScreen(),
  ));
}

class GpsSpeedScreen extends StatefulWidget {
  const GpsSpeedScreen({super.key});

  @override
  State<GpsSpeedScreen> createState() => _GpsSpeedScreenState();
}

class _GpsSpeedScreenState extends State<GpsSpeedScreen> {
  double _rawSpeedKmh = 0.0;
  double _filteredSpeedKmh = 0.0;
  String _filterType = 'kalman';

  // Biến lọc EMA & Kalman
  final double _emaAlpha = 0.3;
  double _kalmanQ = 0.1;
  double _kalmanR = 2.0;
  double _kalmanP = 1.0;
  double _kalmanK = 0.0;

  StreamSubscription<Position>? _positionStreamSubscription;
  String _statusMessage = 'Đang đợi GPS...';

  @override
  void initState() {
    super.initState();
    _initGps();
  }

  Future<void> _initGps() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _statusMessage = 'Hãy bật GPS trên iPhone!');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _statusMessage = 'Chưa cấp quyền vị trí.');
        return;
      }
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      double speedMps = position.speed < 0 ? 0 : position.speed;
      double rawKmh = speedMps * 3.6;

      setState(() {
        _rawSpeedKmh = rawKmh;
        if (_filterType == 'ema') {
          _filteredSpeedKmh = (_emaAlpha * rawKmh) + ((1 - _emaAlpha) * _filteredSpeedKmh);
        } else if (_filterType == 'kalman') {
          _kalmanP = _kalmanP + _kalmanQ;
          _kalmanK = _kalmanP / (_kalmanP + _kalmanR);
          _filteredSpeedKmh = _filteredSpeedKmh + _kalmanK * (rawKmh - _filteredSpeedKmh);
          _kalmanP = (1 - _kalmanK) * _kalmanP;
        } else {
          _filteredSpeedKmh = rawKmh;
        }
        _statusMessage = 'GPS OK - Đang nhận dữ liệu';
      });
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Đo Tốc Độ GPS'),
        centerTitle: true,
        backgroundColor: Colors.black45,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'kalman', label: Text('Kalman')),
                ButtonSegment(value: 'ema', label: Text('EMA')),
                ButtonSegment(value: 'raw', label: Text('Gốc')),
              ],
              selected: {_filterType},
              onSelectionChanged: (val) => setState(() => _filterType = val.first),
            ),
            const SizedBox(height: 40),
            Text(
              _filteredSpeedKmh.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 90,
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent,
              ),
            ),
            const Text(
              'KM/H',
              style: TextStyle(fontSize: 18, color: Colors.grey, letterSpacing: 2),
            ),
            const SizedBox(height: 20),
            Text(
              'Gốc từ GPS: ${_rawSpeedKmh.toStringAsFixed(1)} km/h',
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 30),
            Text(_statusMessage, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
