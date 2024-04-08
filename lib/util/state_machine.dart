import 'package:logging/logging.dart';

final _log = Logger("State Machine Helper");

class StateMachine {
  dynamic currentState;
  dynamic _lastState;
  bool _onEntryHandled = false;

  StateMachine(initialState) {
    currentState = initialState;
    _lastState = initialState;
  }

  void changeIf(bool condition, newState, {Function? transitionTask}) {
    if (condition) {
      _lastState = currentState;
      currentState = newState;
      _onEntryHandled = false;

      if (transitionTask != null) {
        _log.info("State machine: Executing transitionTask");
        transitionTask();
      }

      _log.info("State machine: Changed from $_lastState → $currentState");
    }
  }

  void onEntry(Function task) {
    if (_onEntryHandled == false) {
      _log.info("State machine: Executing onEntry task");
      task();
      _onEntryHandled = true;
    }
  }
}
