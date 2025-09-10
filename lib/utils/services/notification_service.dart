// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;



Future<void> handleBackgroundNotifications(RemoteMessage message) async {
  print(
    'Background notification: ${message.notification?.title}, ${message.notification?.body}, ${message.data}',
  );
}

class NotificationsServices {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  final AndroidNotificationChannel _androidChannel =
      const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notification',
    description: 'This channel is used for important notifications',
    importance: Importance.defaultImportance,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  void handleMessage(RemoteMessage? message) {}

  Future<void> initLocalNotifications() async {
    const ios = DarwinInitializationSettings();
    const android = AndroidInitializationSettings('@drawable/ic_launcher');
    const settings = InitializationSettings(android: android, iOS: ios);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse payload) {
        if (payload.payload != null) {
          final message = RemoteMessage.fromMap(jsonDecode(payload.payload!));
          handleMessage(message);
        }
      },
    );

    final platform = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await platform?.createNotificationChannel(_androidChannel);
  }

  Future<void> initPushNotifications() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.instance.getInitialMessage().then(handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);
    FirebaseMessaging.onBackgroundMessage(handleBackgroundNotifications);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      const darwinDetails = DarwinNotificationDetails();

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            icon: '@drawable/ic_launcher',
          ),
          iOS: darwinDetails,
        ),
        payload: jsonEncode(message.toMap()),
      );
    });
  }

  Future<void> initNotifications() async {
    final fcmToken = await _firebaseMessaging.getToken();
    print('FCM token: $fcmToken');
    if (fcmToken != null) {
      //await ApiCalls.sendFCMToken(fcmToken);
    }
    await initPushNotifications();
    await initLocalNotifications();
  }
}

Future<void> sendFcmTokenToThingsBoard({
  required String fcmToken,
  required String deviceAccessToken,
}) async {
  final url = Uri.parse('http://77.245.2.171:8080/api/v1/$deviceAccessToken/attributes');

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: '{"fcmToken": "$fcmToken"}',
  );

  if (response.statusCode == 200) {
    print("Token sent to ThingsBoard successfully.");
  } else {
    print("Failed to send token: ${response.body}");
  }
}

Future<void> initFCMAndSendToTB(String deviceAccessToken) async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  String? token = await messaging.getToken();

  if (token != null) {
    await sendFcmTokenToThingsBoard(fcmToken: token, deviceAccessToken: 'XBGUh2xrQFSL3xOR6qOG');
  }

  // Handle token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    sendFcmTokenToThingsBoard(fcmToken: newToken, deviceAccessToken: 'XBGUh2xrQFSL3xOR6qOG');
  });
}