import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:multicamera_tracking/shared/domain/events/surveillance_event.dart';

class SurveillanceEventBus {
  SurveillanceEventBus() : id = const Uuid().v4() {
    debugPrint('[BUS] created id=$id hash=${identityHashCode(this)}');
  }

  final String id;
  final _ctrl = StreamController<SurveillanceEvent>.broadcast();

  Stream<SurveillanceEvent> get stream => _ctrl.stream;

  void emit(SurveillanceEvent e) {
    debugPrint('[BUS $id] emit ${e.runtimeType}');
    _ctrl.add(e);
  }

  void dispose() {
    debugPrint('[BUS $id] dispose');
    _ctrl.close();
  }
}
