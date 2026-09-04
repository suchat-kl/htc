import 'dart:async';

import 'package:highway_training/utils/logger.dart';

class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal() {
    if (AppLogger.on) AppLogger.d('🔧 EventBus initialized');
  }

  final _controller = StreamController<String>.broadcast();

  Stream<String> get stream {
    if (AppLogger.on) AppLogger.d('📡 Stream accessed');
    return _controller.stream;
  }

  void emit(String event) {
    if (AppLogger.on) AppLogger.d('📤 EventBus emit: $event');
    _controller.add(event);
  }

  void dispose() {
    if (AppLogger.on) AppLogger.d('🔧 EventBus disposed');
    _controller.close();
  }
}
