import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

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
  int _selectedSortIndex = 0;

  void addChattingRoom(String roomName) {
    setState(() {
      final newRoom = Room(name: roomName, id: DateTime.now().toString());
      chattingRooms.add(newRoom);
      _sortRooms();
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

  void _sortRooms() {
    setState(() {
      chattingRooms.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        if (_selectedSortIndex == 0) {
          return a.name.compareTo(b.name);
        } else {
          return (b.lastMessageTime ?? DateTime.now())
              .compareTo(a.lastMessageTime ?? DateTime.now());
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chatting',
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
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
          final room = chattingRooms[index];

          final now = DateTime.now();
          String timeDisplay;
          if (room.lastMessageTime != null) {
            final difference = now.difference(room.lastMessageTime!);
            if (difference.inDays > 1) {
              timeDisplay = DateFormat('MM/dd').format(room.lastMessageTime!);
            } else if (difference.inDays == 1) {
              timeDisplay = 'Yesterday';
            } else {
              timeDisplay = DateFormat('HH:mm').format(room.lastMessageTime!);
            }
          } else {
            timeDisplay = '';
          }

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, color: Colors.white),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    room.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (room.isPinned)
                  const Icon(Icons.push_pin, size: 16, color: Colors.orange),
              ],
            ),
            subtitle: Text(
              room.lastMessage.isEmpty ? 'No messages yet' : room.lastMessage,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeDisplay,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${room.messages.length}', // 전체 메시지 개수로 변경
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChattingScreen(room: room),
                ),
              ).then((_) {
                setState(() {});
              });
            },
            onLongPress: () {
              setState(() {
                room.isPinned = !room.isPinned;
                _sortRooms();
              });
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedSortIndex,
        onTap: (index) {
          setState(() {
            _selectedSortIndex = index;
            _sortRooms();
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Sort by name',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Sort by date',
          ),
        ],
      ),
    );
  }
}

class Room {
  final String name;
  final String id;
  String lastMessage;
  DateTime? lastMessageTime;
  bool isPinned;
  List<String> messages;

  Room({
    required this.name,
    required this.id,
    this.lastMessage = '',
    this.isPinned = false,
    DateTime? lastMessageTime,
  })  : lastMessageTime = lastMessageTime ?? DateTime.now(),
        messages = [];
}

class ChattingScreen extends StatefulWidget {
  final Room room;

  const ChattingScreen({super.key, required this.room});

  @override
  State<ChattingScreen> createState() => _ChattingScreenState();
}

class _ChattingScreenState extends State<ChattingScreen> {
  final TextEditingController controller = TextEditingController();
  String? pinnedMessage;

  void sendMessage() {
    if (controller.text.isNotEmpty) {
      final userMessage = controller.text;
      setState(() {
        widget.room.messages.add("User: $userMessage");
        widget.room.lastMessage = userMessage;
        widget.room.lastMessageTime = DateTime.now();
        controller.clear();
      });
      _sendMessage(userMessage);
    }
  }

  Future<void> _sendMessage(String message) async {
    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization':
            'Bearer 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',
      },
      body: json.encode({
        'model': 'llama3-8b-8192',
        'messages': [
          {'role': 'user', 'content': message}
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final apiResponse = data['choices'][0]['message']['content'];
      setState(() {
        widget.room.messages.add("Llama: $apiResponse");
        widget.room.lastMessage = apiResponse;
        widget.room.lastMessageTime = DateTime.now();
      });
    } else {
      setState(() {
        final errorMessage =
            'Llama: Failed to get response. Status: ${response.statusCode}';
        widget.room.messages.add(errorMessage);
        widget.room.lastMessage = errorMessage;
        widget.room.lastMessageTime = DateTime.now();
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
          if (pinnedMessage != null)
            Container(
              padding: const EdgeInsets.all(12.0),
              color: Colors.amberAccent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      pinnedMessage!,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        pinnedMessage = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.room.messages.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onLongPress: () {
                    setState(() {
                      pinnedMessage = widget.room.messages[index];
                    });
                  },
                  child: ListTile(
                    title: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: index.isEven ? Colors.orange : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(widget.room.messages[index]),
                    ),
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
