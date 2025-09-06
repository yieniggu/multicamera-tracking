import 'dart:async';
import 'package:multicamera_tracking/shared/domain/events/surveillance_event.dart';

class SurveillanceEventBus {
  final _ctrl = StreamController<SurveillanceEvent>.broadcast();

  Stream<SurveillanceEvent> get stream => _ctrl.stream;

  void emit(SurveillanceEvent e) => _ctrl.add(e);

  void dispose() => _ctrl.close();
}
