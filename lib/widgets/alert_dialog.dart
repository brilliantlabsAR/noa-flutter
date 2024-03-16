// This shows a CupertinoModalPopup which hosts a CupertinoAlertDialog.
import 'package:flutter/cupertino.dart';

void alertDialog(BuildContext context, String alertTitle, String alertString) {
  showCupertinoDialog(
    context: context,
    builder: (BuildContext context) => CupertinoAlertDialog(
      title: Text(alertTitle),
      content: Text(alertString),
      actions: <CupertinoDialogAction>[
        CupertinoDialogAction(
          /// This parameter indicates this action is the default,
          /// and turns the action's text to bold text.
          isDefaultAction: true,
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Okay'),
        ),
      ],
    ),
  );
}
