import 'package:chat_app/model/api_key_model.dart';
import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var meessageString = '';

  void getMyDeviceToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    print('token: $token');
  }

  @override
  void initState() {
    getMyDeviceToken();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        FlutterLocalNotificationsPlugin().show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              "high_importance_channel",
              "high_importance_notification",
              importance: Importance.max,
            ),
          ),
        );
        setState(() {
          meessageString = notification.body!;
          print('meessageString: $meessageString');
        });
      }
    });
    super.initState();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _openAI = OpenAI.instance.build(
    token: OPEN_API_KEY,
    baseOption: HttpSetup(
      receiveTimeout: const Duration(
        seconds: 5,
      ),
    ),
    enableLog: true,
  );

  final ChatUser _currentUser =
      ChatUser(id: "1", firstName: "Chanbeen", lastName: "Kim");
  final ChatUser _gptChatUser =
      ChatUser(id: "2", firstName: "Chat", lastName: "Gpt");

  final List<ChatMessage> _messages = <ChatMessage>[];
  final List<ChatUser> _typingUsers = <ChatUser>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green[600],
          title: const Text("GPT Chat"),
        ),
        body: Column(
          children: [
            Text("message: $meessageString"),
            DashChat(
                currentUser: _currentUser,
                typingUsers: _typingUsers,
                messageOptions: const MessageOptions(
                    currentUserContainerColor: Colors.black,
                    containerColor: Colors.blue,
                    textColor: Colors.white),
                onSend: (ChatMessage m) {
                  getChatResponse(m);
                },
                messages: _messages),
          ],
        ));
  }

  Future<void> getChatResponse(ChatMessage m) async {
    setState(() {
      _messages.insert(0, m);
      _typingUsers.add(_gptChatUser);
    });
    List<Messages> messagesHistory = _messages.reversed.map((m) {
      if (m.user == _currentUser) {
        return Messages(role: Role.user, content: m.text);
      } else {
        return Messages(role: Role.assistant, content: m.text);
      }
    }).toList();
    final request = ChatCompleteText(
      model: GptTurbo0301ChatModel(),
      messages: messagesHistory,
      maxToken: 20,
    );
    final response = await _openAI.onChatCompletion(request: request);
    for (var element in response!.choices) {
      if (element.message != null) {
        setState(
          () {
            _messages.insert(
              0,
              ChatMessage(
                user: _gptChatUser,
                createdAt: DateTime.now(),
                text: element.message!.content,
              ),
            );
          },
        );
      }
    }
    setState(() {
      _typingUsers.remove(_gptChatUser);
    });
    saveMessageToFirestore(m);
  }

  Stream<QuerySnapshot> getMessages() {
    return _firestore.collection('messages').orderBy('createdAt').snapshots();
  }

  Future<void> saveMessageToFirestore(ChatMessage m) async {
    try {
      await _firestore.collection('messages').add({
        'user': _currentUser.id,
        'createdAt': DateTime.now(),
        'text': m.text,
      });
    } catch (e) {
      print('Error saving message to Firestore: $e');
    }
  }
}
