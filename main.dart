import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: MainRoom());
  }
}

class MainRoom extends StatefulWidget {
  const MainRoom({super.key});

  @override
  State<MainRoom> createState() => _MainRoomState();
}

class _MainRoomState extends State<MainRoom> {
  final List<Room> chattingRooms = [];

  void addChattingRoom(String roomName) {
    setState(() {
      final newRoom = Room(name: roomName, id: DateTime.now().toString());
      chattingRooms.add(newRoom);
    });
  }

  void chattingRoomDialog() {
    String roomName = '';

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Agent Name'),
            content: TextField(
              onChanged: (value) {
                roomName = value;
              },
              decoration:
                  const InputDecoration(hintText: 'Write down new name.'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (roomName.isNotEmpty) {
                    addChattingRoom(roomName);
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Apply'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatting'),
        actions: [
          const IconButton(
            onPressed: null,
            icon: Icon(Icons.search),
          ),
          IconButton(
            onPressed: chattingRoomDialog,
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          const IconButton(
            onPressed: null,
            icon: Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: chattingRooms.length,
        itemBuilder: (BuildContext context, int index) {
          return ListTile(
            title: Text(chattingRooms[index].name),
            leading: const Icon(
              Icons.person,
              size: 40,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ChattingScreen(room: chattingRooms[index]),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Sort by name',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          label: 'Sort by date',
        ),
      ]),
    );
  }
}

class Room {
  late final String name;
  late final String id;

  Room({
    required this.name,
    required this.id,
  });
}

class ChattingScreen extends StatefulWidget {
  final Room room;

  const ChattingScreen({super.key, required this.room});

  @override
  State<ChattingScreen> createState() => _ChattingScreenState();
}

class _ChattingScreenState extends State<ChattingScreen> {
  final List<String> messages = [];
  final TextEditingController controller = TextEditingController();

  void sendMessage() {
    if (controller.text.isNotEmpty) {
      final userMessage = controller.text;
      setState(() {
        messages.add("User: $userMessage");
        controller.clear();
      });
      _sendMessage(userMessage);
    }
  }

  Future<void> _sendMessage(String message) async {
    final response = await http.post(
      Uri.parse(
          'https://api.groq.com/openai/v1/chat/completions'), // Llama API의 엔드포인트
      headers: {
        'Content-Type': 'application/json',
        'Authorization':
            'Bearer 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',
      },
      body: json.encode({
        'model': 'llama3-8b-8192', // 모델 이름 설정
        'messages': [
          {'role': 'user', 'content': message} // 사용자 메시지
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final apiResponse =
          data['choices'][0]['message']['content']; // Llama의 응답 메시지
      setState(() {
        messages.add("Llama: $apiResponse");
      });
    } else {
      setState(() {
        messages.add(
            'Llama: Failed to get response. Status: ${response.statusCode}');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: index.isEven
                          ? Colors.orange
                          : Colors.grey[300], // 사용자와 Llama의 메시지 색상 구분
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(messages[index]),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Type a message',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                onPressed: sendMessage,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
