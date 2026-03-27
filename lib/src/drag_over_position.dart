import 'package:flutter/widgets.dart';

class DragOverPosition extends ValueNotifier<bool> {
  DragOverPosition() : super(false);

  bool get enable => value;

  set enable(bool newValue) {
    value = newValue;
  }
}
