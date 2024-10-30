import 'package:flutter/material.dart';

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
      setState(() {
        messages.add(controller.text);
        controller.clear();
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
                    padding: const EdgeInsets.all(8.0), // 텍스트 주변에 여백 추가
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8.0), // 모서리를 둥글게
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

-------------------------------------------------------------------------------------------------------------------------------------

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
    return const MaterialApp(
      home: LlamaChatScreen(),
    );
  }
}

class LlamaChatScreen extends StatefulWidget {
  const LlamaChatScreen({super.key});

  @override
  State<LlamaChatScreen> createState() => _LlamaChatScreenState();
}

class _LlamaChatScreenState extends State<LlamaChatScreen> {
  final TextEditingController _controller = TextEditingController();
  String _response = '';

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
      setState(() {
        _response = data['choices'][0]['message']['content']; // Llama의 응답 메시지
      });
    } else {
      setState(() {
        _response = 'Failed to get response. Status: ${response.statusCode}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Llama Chat')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Enter your message',
              ),
            ),
            const SizedBox(height: 8.0),
            ElevatedButton(
              onPressed: () {
                final message = _controller.text;
                if (message.isNotEmpty) {
                  _sendMessage(message); // Llama API 호출
                  _controller.clear(); // 입력 필드 초기화
                }
              },
              child: const Text('Send'),
            ),
            const SizedBox(height: 16.0),
            const Text(
              'Response from Llama:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            Text(_response), // Llama의 응답 표시
          ],
        ),
      ),
    );
  }
}
