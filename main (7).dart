// main.dart
// App đo tốc độ bằng GPS - Flutter
// Có đồng hồ kim (analog gauge), nút tạm dừng/tiếp tục, bản đồ khi xoay ngang máy

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const SpeedoApp());
}

class SpeedoApp extends StatelessWidget {
  const SpeedoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Đo tốc độ GPS',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const SpeedHomePage(),
    );
  }
}

class SpeedHomePage extends StatefulWidget {
  const SpeedHomePage({super.key});

  @override
  State<SpeedHomePage> createState() => _SpeedHomePageState();
}

class _SpeedHomePageState extends State<SpeedHomePage> {
  StreamSubscription<Position>? _positionStream;
  final MapController _mapController = MapController();

  // Tốc độ tối đa hiển thị trên mặt đồng hồ kim (km/h) - chỉnh số này nếu muốn thang đo khác
  static const double gaugeMaxSpeed = 200;

  double _speedKmh = 0.0;
  double _maxSpeedKmh = 0.0;
  double _accuracy = 0.0;
  String _status = 'Đang khởi động...';
  bool _isPaused = false;
  LatLng? _currentLatLng;
  bool _mapReady = false;

  // Lưu vị trí + thời gian lần cập nhật trước, dùng để tự tính tốc độ
  // (đáng tin cậy hơn trường "speed" do hệ thống trả về, vốn có thể sai trên 1 số máy)
  _SimplePoint? _lastPosition;
  DateTime? _lastTimestamp;
  double _debugLastDistanceMeters = 0.0;
  double _debugLastSeconds = 0.0;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _status = 'Vui lòng bật GPS trong Cài đặt');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _status = 'Bạn đã từ chối quyền truy cập vị trí');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _status = 'Quyền vị trí bị chặn vĩnh viễn, vào Cài đặt để bật lại');
      return;
    }

    setState(() => _status = 'Đang đo...');

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      if (_isPaused) return;
      _processNewFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        systemSpeed: position.speed,
      );
    }, onError: (e) {
      setState(() => _status = 'Lỗi GPS: $e');
    });
  }

  // Xử lý 1 điểm tọa độ mới (dùng chung cho cả GPS thật và chế độ giả lập test)
  void _processNewFix({
    required double latitude,
    required double longitude,
    required double accuracy,
    required double systemSpeed,
  }) {
    final now = DateTime.now();
    double speedKmh;

    // Ưu tiên tự tính tốc độ từ khoảng cách di chuyển thực tế giữa 2 lần cập nhật,
    // vì trường "speed" do hệ thống trả về có thể không chính xác trên một số máy.
    if (_lastPosition != null && _lastTimestamp != null) {
      final distanceMeters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        latitude,
        longitude,
      );
      final seconds = now.difference(_lastTimestamp!).inMilliseconds / 1000.0;
      _debugLastDistanceMeters = distanceMeters;
      _debugLastSeconds = seconds;

      if (seconds > 0.3) {
        final calculatedSpeedMs = distanceMeters / seconds;
        speedKmh = calculatedSpeedMs * 3.6;
      } else {
        speedKmh = _speedKmh;
      }
    } else {
      final speedMs = systemSpeed < 0 ? 0.0 : systemSpeed;
      speedKmh = speedMs * 3.6;
    }

    _lastPosition = _SimplePoint(latitude: latitude, longitude: longitude);
    _lastTimestamp = now;

    final newLatLng = LatLng(latitude, longitude);

    setState(() {
      _speedKmh = speedKmh;
      _accuracy = accuracy;
      _currentLatLng = newLatLng;
      if (speedKmh > _maxSpeedKmh) {
        _maxSpeedKmh = speedKmh;
      }
    });

    if (_mapReady) {
      try {
        _mapController.move(newLatLng, _mapController.camera.zoom);
      } catch (_) {}
    }
  }

  // ---- Chế độ giả lập di chuyển để test khi không muốn ra ngoài đường ----
  Timer? _simulationTimer;
  bool _isSimulating = false;
  double _simLat = 21.0285; // tọa độ khởi điểm giả lập (Hà Nội, chỉ để có điểm bắt đầu)
  double _simLng = 105.8542;

  void _toggleSimulation() {
    if (_isSimulating) {
      _simulationTimer?.cancel();
      setState(() {
        _isSimulating = false;
        _status = 'Đã tắt giả lập';
      });
      return;
    }

    // Giả lập di chuyển thẳng với tốc độ cố định ~40 km/h để kiểm tra logic tính toán
    const double simulatedSpeedKmh = 40.0;
    final double metersPerSecond = simulatedSpeedKmh / 3.6;
    // 1 độ vĩ độ ~ 111320 mét, mỗi giây di chuyển 1 khoảng lat tương ứng
    final double latIncrementPerSecond = metersPerSecond / 111320;

    _lastPosition = null;
    _lastTimestamp = null;

    setState(() {
      _isSimulating = true;
      _status = 'Đang giả lập ~$simulatedSpeedKmh km/h (test, không cần ra đường)';
    });

    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _simLat += latIncrementPerSecond;
      _processNewFix(
        latitude: _simLat,
        longitude: _simLng,
        accuracy: 5.0,
        systemSpeed: -1,
      );
    });
  }

  void _resetMax() {
    setState(() => _maxSpeedKmh = 0.0);
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      _status = _isPaused ? 'Đã tạm dừng' : 'Đang đo...';
      if (!_isPaused) {
        // Xóa điểm mốc cũ khi tiếp tục đo, tránh tính khoảng cách nhảy cóc
        // trong lúc tạm dừng thành tốc độ ảo cực lớn
        _lastPosition = null;
        _lastTimestamp = null;
      }
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _simulationTimer?.cancel();
    super.dispose();
  }

  // Đồng hồ kim - vẽ tay bằng CustomPainter, không cần thêm package ngoài
  Widget _buildSpeedGauge(double gaugeSize) {
    return SizedBox(
      width: gaugeSize,
      height: gaugeSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(gaugeSize, gaugeSize),
            painter: SpeedGaugePainter(
              speed: _speedKmh,
              maxSpeed: gaugeMaxSpeed,
            ),
          ),
          Positioned(
            bottom: gaugeSize * 0.22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _speedKmh.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: gaugeSize * 0.16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'km/h',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedDisplay(double gaugeSize) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _status,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 8),
        _buildSpeedGauge(gaugeSize),
        const SizedBox(height: 12),
        Text(
          'Tốc độ tối đa: ${_maxSpeedKmh.toStringAsFixed(1)} km/h',
          style: const TextStyle(fontSize: 16, color: Colors.orangeAccent),
        ),
        Text(
          'Độ chính xác GPS: ±${_accuracy.toStringAsFixed(1)} m',
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        if (_currentLatLng != null)
          Text(
            'Tọa độ (debug): ${_currentLatLng!.latitude.toStringAsFixed(6)}, '
            '${_currentLatLng!.longitude.toStringAsFixed(6)}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        Text(
          'Debug: ${_debugLastDistanceMeters.toStringAsFixed(2)} m / '
          '${_debugLastSeconds.toStringAsFixed(2)} s',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _togglePause,
              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
              label: Text(_isPaused ? 'Tiếp tục' : 'Tạm dừng'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isPaused ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _resetMax,
              child: const Text('Reset tối đa'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _toggleSimulation,
          icon: Icon(_isSimulating ? Icons.stop : Icons.science),
          label: Text(_isSimulating
              ? 'Tắt giả lập (~40 km/h)'
              : 'Test giả lập di chuyển (ngồi yên)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isSimulating ? Colors.red : Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildMap() {
    if (_currentLatLng == null) {
      return const Center(
        child: Text(
          'Đang chờ tín hiệu GPS để hiện bản đồ...',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mapReady) {
        setState(() => _mapReady = true);
      }
    });

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLatLng!,
        initialZoom: 16,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.speedo_app',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: _currentLatLng!,
              width: 40,
              height: 40,
              child: const Icon(
                Icons.navigation,
                color: Colors.cyanAccent,
                size: 32,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tốc độ GPS'),
        backgroundColor: Colors.black,
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            return Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Center(child: _buildSpeedDisplay(220)),
                ),
                const VerticalDivider(width: 1, color: Colors.white24),
                Expanded(
                  flex: 1,
                  child: _buildMap(),
                ),
              ],
            );
          }
          return Center(child: _buildSpeedDisplay(280));
        },
      ),
    );
  }
}

// Lớp vẽ mặt đồng hồ kim + kim quay theo tốc độ hiện tại
class SpeedGaugePainter extends CustomPainter {
  final double speed;
  final double maxSpeed;

  SpeedGaugePainter({required this.speed, required this.maxSpeed});

  static const double startAngleDeg = 135; // vị trí bắt đầu vòng cung (độ)
  static const double sweepAngleDeg = 270; // độ rộng vòng cung, chừa khoảng trống phía dưới

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 24;
    final progress = (speed / maxSpeed).clamp(0.0, 1.0);

    // Vòng cung nền màu xám mờ
    final bgPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngleDeg * pi / 180,
      sweepAngleDeg * pi / 180,
      false,
      bgPaint,
    );

    // Vòng cung màu thể hiện mức tốc độ hiện tại (xanh thấp -> đỏ cao)
    final progressPaint = Paint()
      ..color = Color.lerp(Colors.greenAccent, Colors.redAccent, progress) ??
          Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngleDeg * pi / 180,
      sweepAngleDeg * pi / 180 * progress,
      false,
      progressPaint,
    );

    // Vạch chia số quanh mặt đồng hồ
    final tickPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2;
    const tickStep = 20;
    final tickCount = (maxSpeed / tickStep).round();
    for (int i = 0; i <= tickCount; i++) {
      final tickValue = i * tickStep;
      final angle = (startAngleDeg + sweepAngleDeg * (tickValue / maxSpeed)) * pi / 180;
      final outerPoint = Offset(
        center.dx + (radius + 10) * cos(angle),
        center.dy + (radius + 10) * sin(angle),
      );
      final innerPoint = Offset(
        center.dx + (radius - 8) * cos(angle),
        center.dy + (radius - 8) * sin(angle),
      );
      canvas.drawLine(innerPoint, outerPoint, tickPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$tickValue',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelPoint = Offset(
        center.dx + (radius - 28) * cos(angle) - textPainter.width / 2,
        center.dy + (radius - 28) * sin(angle) - textPainter.height / 2,
      );
      textPainter.paint(canvas, labelPoint);
    }

    // Kim đồng hồ
    final needleAngle = (startAngleDeg + sweepAngleDeg * progress) * pi / 180;
    final needleLength = radius - 22;
    final needleEnd = Offset(
      center.dx + needleLength * cos(needleAngle),
      center.dy + needleLength * sin(needleAngle),
    );
    final needlePaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);

    // Tâm kim
    canvas.drawCircle(center, 8, Paint()..color = Colors.white);
    canvas.drawCircle(center, 8, Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant SpeedGaugePainter oldDelegate) {
    return oldDelegate.speed != speed || oldDelegate.maxSpeed != maxSpeed;
  }
}

// Class đơn giản chỉ lưu kinh độ/vĩ độ, dùng chung cho cả GPS thật và tọa độ giả lập
class _SimplePoint {
  final double latitude;
  final double longitude;
  const _SimplePoint({required this.latitude, required this.longitude});
}
