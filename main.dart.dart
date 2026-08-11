import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SpeedometerApp());
}

class SpeedometerApp extends StatelessWidget {
  const SpeedometerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Đo Tốc Độ GPS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Colors.lightBlueAccent,
        ),
      ),
      home: const SpeedometerScreen(),
    );
  }
}

class SpeedometerScreen extends StatefulWidget {
  const SpeedometerScreen({super.key});

  @override
  State<SpeedometerScreen> createState() => _SpeedometerScreenState();
}

class _SpeedometerScreenState extends State<SpeedometerScreen> {
  double _rawSpeedKmh = 0.0;
  double _filteredSpeedKmh = 0.0;
  
  // Trạng thái bộ lọc: 'kalman', 'ema', hoặc 'raw'
  String _filterType = 'kalman'; 

  // Thuật toán EMA (Exponential Moving Average)
  final double _emaAlpha = 0.3; // Hệ số làm mượt (0 < alpha <= 1)

  // Thuật toán Kalman Filter đơn giản cho 1 chiều (tốc độ)
  double _kalmanQ = 0.1;  // Nhiễu quá trình (Process Noise)
  double _kalmanR = 2.0;  // Nhiễu đo lường GPS (Measurement Noise)
  double _kalmanP = 1.0;  // Ước lượng sai số hệ thống
  double _kalmanK = 0.0;  // Kalman Gain

  StreamSubscription<Position>? _positionStreamSubscription;
  String _statusMessage = 'Đang khởi tạo GPS...';

  @override
  void initState() {
    super.initState();
    _initGps();
  }

  Future<void> _initGps() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _statusMessage = 'Vui lòng bật Định vị (GPS) trên máy!');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _statusMessage = 'Từ chối quyền vị trí.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _statusMessage = 'Quyền vị trí bị từ chối vĩnh viễn.');
      return;
    }

    setState(() => _statusMessage = 'Đang nhận tín hiệu GPS...');

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      // Geolocator trả về m/s, đổi sang km/h
      double speedMps = position.speed < 0 ? 0 : position.speed;
      double rawKmh = speedMps * 3.6;

      _applyFilter(rawKmh);
    });
  }

  void _applyFilter(double rawKmh) {
    setState(() {
      _rawSpeedKmh = rawKmh;

      if (_filterType == 'ema') {
        // Thuật toán EMA: S_t = alpha * Y_t + (1 - alpha) * S_{t-1}
        _filteredSpeedKmh = (_emaAlpha * rawKmh) + ((1 - _emaAlpha) * _filteredSpeedKmh);
      } else if (_filterType == 'kalman') {
        // Bước Dự Báo (Predict)
        _kalmanP = _kalmanP + _kalmanQ;

        // Bước Cập Nhật (Update)
        _kalmanK = _kalmanP / (_kalmanP + _kalmanR);
        _filteredSpeedKmh = _filteredSpeedKmh + _kalmanK * (rawKmh - _filteredSpeedKmh);
        _kalmanP = (1 - _kalmanK) * _kalmanP;
      } else {
        _filteredSpeedKmh = rawKmh;
      }
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
      appBar: AppBar(
        title: const Text('Đo Tốc Độ GPS'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Bảng chọn Bộ Lọc
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'kalman', label: Text('Kalman')),
                  ButtonSegment(value: 'ema', label: Text('EMA')),
                  ButtonSegment(value: 'raw', label: Text('Gốc (Raw)')),
                ],
                selected: {_filterType},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _filterType = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 50),

              // Hiển thị tốc độ đã qua lọc
              FittedBox(
                child: Text(
                  _filteredSpeedKmh.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 100,
                    fontWeight: FontWeight.bold,
                    color: Colors.lightBlueAccent,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const Text(
                'KM/H',
                style: TextStyle(
                  fontSize: 20,
                  letterSpacing: 4,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30),

              // Tốc độ gốc từ GPS
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'GPS Raw: ${_rawSpeedKmh.toStringAsFixed(1)} km/h',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
              const SizedBox(height: 40),

              // Trạng thái GPS
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}