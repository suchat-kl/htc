import 'dart:async';

import 'package:flutter/foundation.dart';

class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal() {
    debugPrint('🔧 EventBus initialized');
  }

  final _controller = StreamController<String>.broadcast();

  Stream<String> get stream {
    debugPrint('📡 Stream accessed');
    return _controller.stream;
  }

  void emit(String event) {
    debugPrint('📤 EventBus emit: $event');
    _controller.add(event);
  }

  void dispose() {
    debugPrint('🔧 EventBus disposed');
    _controller.close();
  }
}
