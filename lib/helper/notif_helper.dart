import 'dart:developer';

import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotifiHelper {
  NotifiHelper._();

  static Future<void> initNotif() async {
    await OneSignal.shared.setLogLevel(OSLogLevel.verbose, OSLogLevel.none);

    await OneSignal.shared.setAppId("YOUR_ONESIGNAL_APP_ID");

    await OneSignal.shared
        .promptUserForPushNotificationPermission()
        .then((pushNotificationPermission) {
      log("Permission Accepted $pushNotificationPermission");
    });
  }
}
