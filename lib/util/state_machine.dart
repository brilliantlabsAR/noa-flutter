import 'package:logging/logging.dart';

final _log = Logger("State Machine Helper");

class StateMachine {
  dynamic current;
  dynamic _next;
  dynamic _event;
  bool _onEntryHandled = false;

  StateMachine(initialState) {
    current = initialState;
    _next = initialState;
  }

  void event(event) {
    _event = event;
  }

  void changeOn(event, next, {Function? transitionTask}) {
    if (event == _event) {
      _event = null;
      _next = next;
      _onEntryHandled = false;

      if (transitionTask != null) {
        _log.info("State machine: Executing transitionTask");
        transitionTask();
      }

      _log.info("State machine: $event triggered change $current → $next");
    }
  }

  bool changePending() {
    if (_next == current) {
      return false;
    }

    current = _next;
    return true;
  }

  void onEntry(Function task) {
    if (_onEntryHandled == false) {
      _log.info("State machine: Executing onEntry task");
      task();
      _onEntryHandled = true;
    }
  }
}
