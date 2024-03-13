class NoaMessageModel {
  String message;
  String from;
  DateTime time;

  NoaMessageModel({
    required this.message,
    required this.from,
    required this.time,
  });

  static NoaMessageModel addMessage(
    String message,
    String from,
    DateTime time,
  ) {
    return NoaMessageModel(message: message, from: from, time: time);
  }
}
