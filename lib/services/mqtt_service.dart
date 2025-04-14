import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/sensor_data.dart';

/// Сервис для работы с MQTT
class MqttService {
  // MQTT константы
  static const String broker = "193.43.147.210";
  static const int port = 1883;
  static const String username = "timur";
  static const String password = "timur_1972";
  static const String topicDht = "esp32/sensor/dht";
  static const String topicRgb = "esp32/control/rgb";

  // MQTT клиент
  MqttServerClient? _client;
  bool _isConnected = false;
  String _connectionStatus = "Отключено";

  // Стримы для передачи данных
  final _sensorDataStreamController = StreamController<SensorData>.broadcast();
  final _connectionStatusController = StreamController<String>.broadcast();

  // Геттеры для доступа к стримам
  Stream<SensorData> get sensorDataStream => _sensorDataStreamController.stream;
  Stream<String> get connectionStatusStream =>
      _connectionStatusController.stream;

  // Геттер для проверки статуса соединения
  bool get isConnected => _isConnected;

  // Геттер для получения статуса соединения
  String get connectionStatus => _connectionStatus;

  // Конструктор
  MqttService() {
    _setupMqttClient();
  }

  // Настройка MQTT клиента
  void _setupMqttClient() {
    final String clientId =
        'flutter_app_${DateTime.now().millisecondsSinceEpoch}';
    _client = MqttServerClient(broker, clientId);

    // Настройка соединения
    _client!.port = port;
    _client!.keepAlivePeriod = 60;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;
    _client!.logging(on: false);
    _client!.secure = false; // для обычного MQTT (порт 1883)

    // Настройка параметров безопасности
    final connMessage = MqttConnectMessage()
        .authenticateAs(username, password)
        .withWillTopic('willTopic')
        .withWillMessage('Disconnected')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMessage;
  }

  // Подключение к MQTT серверу
  Future<bool> connect() async {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      return true; // Уже подключены
    }

    _updateConnectionStatus("Соединение...");

    try {
      await _client!.connect();
      return _isConnected;
    } catch (e) {
      print('Исключение при подключении к MQTT: $e');
      _updateConnectionStatus("Ошибка: $e");
      return false;
    }
  }

  // Отключение от MQTT сервера
  void disconnect() {
    try {
      _client?.disconnect();
    } catch (e) {
      print('Ошибка при отключении от MQTT: $e');
    }
  }

  // Обработчик успешного подключения
  void _onConnected() {
    _isConnected = true;
    _updateConnectionStatus("Соединено");

    // Подписка на топик с данными датчика
    _client!.subscribe(topicDht, MqttQos.atLeastOnce);

    // Настройка обработчика входящих сообщений
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (var message in messages) {
        final MqttPublishMessage recMess =
            message.payload as MqttPublishMessage;
        final String payload = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );

        _processMessage(message.topic, payload);
      }
    });
  }

  // Обработка входящих сообщений
  void _processMessage(String topic, String payload) {
    if (topic == topicDht) {
      try {
        final data = json.decode(payload);
        final sensorData = SensorData.fromJson(data);

        // Отправка данных в стрим
        if (sensorData.temperature > 0 || sensorData.humidity > 0) {
          _sensorDataStreamController.add(sensorData);
        }
      } catch (e) {
        print('Ошибка при обработке данных DHT: $e');
      }
    }
  }

  // Обработчик отключения
  void _onDisconnected() {
    _isConnected = false;
    _updateConnectionStatus("Отключено");
  }

  // Обработчик успешной подписки
  void _onSubscribed(String topic) {
    print('Подписка на топик: $topic');
  }

  // Обновление статуса соединения
  void _updateConnectionStatus(String status) {
    _connectionStatus = status;
    _connectionStatusController.add(status);
  }

  // Публикация данных RGB
  bool publishRgbData(RgbData rgbData) {
    if (!_isConnected) return false;

    try {
      final String payload = json.encode(rgbData.toJson());

      // Публикация данных
      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);

      _client!.publishMessage(topicRgb, MqttQos.atLeastOnce, builder.payload!);

      print('Отправлены данные RGB: $payload');
      return true;
    } catch (e) {
      print('Ошибка при публикации данных RGB: $e');
      return false;
    }
  }

  // Освобождение ресурсов
  void dispose() {
    disconnect();
    _sensorDataStreamController.close();
    _connectionStatusController.close();
  }
}
