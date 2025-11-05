import 'package:event_bus/event_bus.dart';

class MCEventBus {
  static final EventBus _bus = EventBus();

  static Stream<T> on<T>() => _bus.on<T>();

  static void fire(event) => _bus.fire(event);
}

class TabIndexSelectEvent {
  int index = 0;
  TabIndexSelectEvent(this.index);
}

class RefreshCollectEvent {
  RefreshCollectEvent();
}

class PlayerCloseEvent {
  PlayerCloseEvent();
}

class HidetabbarEvent {
  bool isHideTabbar = false;
  HidetabbarEvent(  {this.isHideTabbar = false});
}
