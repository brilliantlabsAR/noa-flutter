import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/style.dart';
import 'package:noa/widgets/top_title_bar.dart';
import 'package:noa/widgets/bottom_nav_bar.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:async'; // Add this import

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  _NotesPageState createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  final Map<int, bool> _expanded = {};
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Load notes when the widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(app.model).loadNotes();
    });

    // Set up a timer to update the UI every minute
    _timer = Timer.periodic(Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(app.model.select((model) => model.notes));
    final now = DateTime.now();

    // Set custom messages for timeago
    timeago.setLocaleMessages('en_short', CustomEnShortMessages());

    return Scaffold(
      backgroundColor: colorWhite,
      appBar: topTitleBar(context, 'NOTES', false, false),
      body: notes.isEmpty
          ? Center(child: Text('No notes available', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                final formattedDate = _formatDate(note.dateTime, now);
                final isExpanded = _expanded[index] ?? false;

                return Dismissible(
                  key: Key(note.dateTime.toString()),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    ref.read(app.model).deleteNoteAt(index);
                  },
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.delete, color: Colors.white),
                        Text('Delete', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _expanded[index] = !isExpanded;
                      });
                    },
                    child: SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        padding: const EdgeInsets.only(
                          top: 15,
                          bottom: 15,
                          left: 42,
                          right: 42,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD4D2D2),
                                  ),
                                ),
                                if (note.content.isNotEmpty)
                                  Icon(
                                    isExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                    color: Colors.grey,
                                  ),
                              ],
                            ),
                            Text(
                              note.title,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 25,
                              ),
                            ),
                            if (isExpanded && note.content.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  note.content,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: bottomNavBar(context, 3, false),
    );
  }

  String _formatDate(DateTime dateTime, DateTime now) {
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return timeago.format(dateTime, locale: 'en_short');
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('jm').format(dateTime)}';
    } else {
      return DateFormat('EEEE d MMMM \'at\' h:mm a').format(dateTime);
    }
  }
}

class CustomEnShortMessages implements timeago.LookupMessages {
  @override
  String prefixAgo() => '';
  @override
  String prefixFromNow() => '';
  @override
  String suffixAgo() => ''; // Default to empty
  @override
  String suffixFromNow() => 'From now';
  @override
  String lessThanOneMinute(int seconds) => 'Just now';
  @override
  String aboutAMinute(int minutes) => 'A minute ago'; // Add "ago" here
  @override
  String minutes(int minutes) => '$minutes minutes ago'; // Add "ago" here
  @override
  String aboutAnHour(int minutes) => 'An hour ago'; // Add "ago" here
  @override
  String hours(int hours) => '$hours hours ago'; // Add "ago" here
  @override
  String aDay(int hours) => 'A day ago'; // Add "ago" here
  @override
  String days(int days) => '$days days ago'; // Add "ago" here
  @override
  String aboutAMonth(int days) => 'A month ago'; // Add "ago" here
  @override
  String months(int months) => '$months months ago'; // Add "ago" here
  @override
  String aboutAYear(int year) => 'A year ago'; // Add "ago" here
  @override
  String years(int years) => '$years years ago'; // Add "ago" here
  @override
  String wordSeparator() => ' ';
}
