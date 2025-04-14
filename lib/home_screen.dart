import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'models/sensor_data.dart';
import 'services/mqtt_service.dart';
import 'services/storage_service.dart';

/// Главный экран приложения с двумя вкладками:
/// 1. Управление RGB-светодиодом
/// 2. Мониторинг температуры и влажности
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Сервисы
  final MqttService _mqttService = MqttService();
  final StorageService _storageService = StorageService();

  // Состояние UI
  Color _ledColor = Colors.red;
  double _brightness = 0.8;
  bool _showSaveMessage = false;

  // Данные для графиков
  double _temperature = 0.0;
  double _humidity = 0.0;
  final List<FlSpot> _temperatureData = List.generate(
    24,
    (i) => FlSpot(i.toDouble(), 0),
  );
  final List<FlSpot> _humidityData = List.generate(
    24,
    (i) => FlSpot(i.toDouble(), 0),
  );

  // Подписки на стримы
  late StreamSubscription _mqttStatusSubscription;
  late StreamSubscription _sensorDataSubscription;

  // Таймер для переподключения
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Загрузка сохранённых настроек
    _loadSavedSettings();

    // Подписка на обновления статуса соединения
    _mqttStatusSubscription = _mqttService.connectionStatusStream.listen((
      status,
    ) {
      setState(() {});
    });

    // Подписка на данные с сенсоров
    _sensorDataSubscription = _mqttService.sensorDataStream.listen((data) {
      _updateSensorData(data);
    });

    // Подключение к MQTT
    _connect();

    // Таймер для переподключения
    _reconnectTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_mqttService.isConnected) {
        _connect();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reconnectTimer?.cancel();
    _mqttStatusSubscription.cancel();
    _sensorDataSubscription.cancel();
    _mqttService.dispose();
    super.dispose();
  }

  /// Подключение к MQTT
  Future<void> _connect() async {
    await _mqttService.connect();

    if (_mqttService.isConnected) {
      _sendRgbSettings();
    }
  }

  /// Загрузка сохраненных настроек
  Future<void> _loadSavedSettings() async {
    // Загрузка RGB настроек
    final rgbData = await _storageService.loadRgbSettings();

    // Загрузка данных сенсоров
    final sensorData = await _storageService.loadLastSensorData();

    setState(() {
      _ledColor = rgbData.color;
      _brightness = rgbData.brightnessValue;

      if (sensorData.temperature > 0) _temperature = sensorData.temperature;
      if (sensorData.humidity > 0) _humidity = sensorData.humidity;
    });
  }

  /// Обновление данных с сенсоров
  void _updateSensorData(SensorData data) {
    setState(() {
      if (data.temperature > 0) _temperature = data.temperature;
      if (data.humidity > 0) _humidity = data.humidity;

      // Обновление графиков
      _updateDataGraphs(_temperature, _humidity);
    });

    // Сохранение данных
    _storageService.saveSensorData(data);
  }

  /// Обновление графиков данными
  void _updateDataGraphs(double temp, double humidity) {
    setState(() {
      // Сдвигаем точки влево
      for (int i = 0; i < _temperatureData.length - 1; i++) {
        _temperatureData[i] = FlSpot(
          _temperatureData[i].x,
          _temperatureData[i + 1].y,
        );
        _humidityData[i] = FlSpot(_humidityData[i].x, _humidityData[i + 1].y);
      }

      // Добавляем новые точки
      _temperatureData[_temperatureData.length - 1] = FlSpot(
        _temperatureData[_temperatureData.length - 1].x,
        temp,
      );

      _humidityData[_humidityData.length - 1] = FlSpot(
        _humidityData[_humidityData.length - 1].x,
        humidity,
      );
    });
  }

  /// Отправка настроек RGB
  void _sendRgbSettings() {
    if (_mqttService.isConnected) {
      final rgbData = RgbData.fromColor(_ledColor, _brightness);
      _mqttService.publishRgbData(rgbData);
    }
  }

  /// Сохранение и отправка настроек
  Future<void> _saveAndSendSettings() async {
    final rgbData = RgbData.fromColor(_ledColor, _brightness);

    // Сохранение в хранилище
    await _storageService.saveRgbData(rgbData);

    // Отправка на сервер
    if (_mqttService.isConnected) {
      _mqttService.publishRgbData(rgbData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Отправлены данные: RGB(${_ledColor.red},${_ledColor.green},${_ledColor.blue}), Яркость: ${(_brightness * 100).toInt()}%',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Нет подключения к серверу, настройки сохранены локально',
          ),
          backgroundColor: Colors.orange,
        ),
      );

      _connect();
    }

    // Показ сообщения о сохранении
    setState(() {
      _showSaveMessage = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showSaveMessage = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = _mqttService.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Умный дом'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // Индикатор состояния соединения
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Icon(
              isConnected ? Icons.wifi : Icons.wifi_off,
              color: isConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.lightbulb), text: 'Управление RGB'),
            Tab(icon: Icon(Icons.thermostat), text: 'Данные датчиков'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              // Первая вкладка - управление RGB светодиодом
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Индикатор состояния сервера
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isConnected ? Colors.green : Colors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isConnected
                                    ? 'Подключено к серверу: ${MqttService.broker}'
                                    : 'Нет подключения к серверу - настройки сохраняются локально',
                                style: TextStyle(
                                  color:
                                      isConnected
                                          ? Colors.green.shade800
                                          : Colors.orange.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (!isConnected)
                              TextButton(
                                onPressed: _connect,
                                child: const Text('Подключиться'),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Карточка с выбором цвета
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Выбор цвета',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: ColorPicker(
                                pickerColor: _ledColor,
                                onColorChanged: (color) {
                                  setState(() {
                                    _ledColor = color;
                                  });
                                },
                                pickerAreaHeightPercent: 0.8,
                                portraitOnly: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Карточка с регулировкой яркости
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Яркость',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.brightness_low),
                                Expanded(
                                  child: Slider(
                                    value: _brightness,
                                    onChanged: (value) {
                                      setState(() {
                                        _brightness = value;
                                      });
                                    },
                                    activeColor: Colors.indigo,
                                  ),
                                ),
                                const Icon(Icons.brightness_high),
                              ],
                            ),
                            Center(
                              child: Text(
                                '${(_brightness * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Кнопка применения настроек
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveAndSendSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'ПРИМЕНИТЬ И СОХРАНИТЬ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Предпросмотр цвета
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Предпросмотр',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: _ledColor.withOpacity(_brightness),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _ledColor.withOpacity(0.5),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                'RGB(${_ledColor.red}, ${_ledColor.green}, ${_ledColor.blue})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Вторая вкладка - график температуры и влажности
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Индикатор состояния сервера
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    isConnected ? Colors.green : Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isConnected
                                    ? 'Получение данных с датчиков в реальном времени'
                                    : 'Отображение сохраненных данных',
                                style: TextStyle(
                                  color:
                                      isConnected
                                          ? Colors.green.shade800
                                          : Colors.orange.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (!isConnected)
                              TextButton(
                                onPressed: _connect,
                                child: const Text('Подключиться'),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      isConnected
                          ? 'Данные с датчиков (реальные)'
                          : 'Данные с датчиков (локально сохраненные)',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Текущие показания
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.thermostat,
                                    color: Colors.red.shade700,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_temperature.toStringAsFixed(1)}°C',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                  const Text('Температура'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.water_drop,
                                    color: Colors.blue.shade700,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_humidity.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  const Text('Влажность'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'График за последние 24 часа',
                      style: TextStyle(color: Colors.grey),
                    ),

                    const SizedBox(height: 8),

                    // График температуры
                    Expanded(
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.thermostat,
                                    color: Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Температура (°C)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: LineChart(
                                  LineChartData(
                                    gridData: const FlGridData(show: true),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          interval: 4,
                                          getTitlesWidget: (value, meta) {
                                            return Text('${value.toInt()}ч');
                                          },
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                    ),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: _temperatureData,
                                        isCurved: true,
                                        color: Colors.red.shade700,
                                        barWidth: 3,
                                        dotData: const FlDotData(show: false),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: Colors.red.withOpacity(0.2),
                                        ),
                                      ),
                                    ],
                                    minY: 15,
                                    maxY: 30,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // График влажности
                    Expanded(
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.water_drop,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Влажность (%)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: LineChart(
                                  LineChartData(
                                    gridData: const FlGridData(show: true),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          interval: 4,
                                          getTitlesWidget: (value, meta) {
                                            return Text('${value.toInt()}ч');
                                          },
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                    ),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: _humidityData,
                                        isCurved: true,
                                        color: Colors.blue.shade700,
                                        barWidth: 3,
                                        dotData: const FlDotData(show: false),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: Colors.blue.withOpacity(0.2),
                                        ),
                                      ),
                                    ],
                                    minY: 20,
                                    maxY: 80,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Индикатор сохранения настроек
          if (_showSaveMessage)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Настройки сохранены',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
