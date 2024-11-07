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
            decoration: const InputDecoration(hintText: 'Write down new name.'),
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
      },
    );
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
                    '${room.messages.length}',
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
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title:
                        Text(room.isPinned ? 'Unstick on top' : 'Stick on top'),
                    content: Text(room.isPinned
                        ? "Do you want to unput '${room.name}' on the top of the list?"
                        : "Do you want to put '${room.name}' on the top of the list?"),
                    actions: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            room.isPinned = !room.isPinned;
                            _sortRooms();
                          });
                          Navigator.of(context).pop(); // Close dialog
                        },
                        child: const Text('Yes'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                        },
                        child: const Text('No'),
                      ),
                    ],
                  );
                },
              );
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
  List<Message> messages;

  Room({
    required this.name,
    required this.id,
    this.lastMessage = '',
    this.isPinned = false,
    DateTime? lastMessageTime,
  })  : lastMessageTime = lastMessageTime ?? DateTime.now(),
        messages = [];
}

class Message {
  final String sender;
  final String content;
  final DateTime timestamp;

  Message({
    required this.sender,
    required this.content,
    required this.timestamp,
  });
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
  final ScrollController _scrollController = ScrollController();

  void sendMessage() {
    if (controller.text.isNotEmpty) {
      final userMessage = controller.text;
      final timestamp = DateTime.now();
      setState(() {
        widget.room.messages.add(Message(
          sender: 'User',
          content: userMessage,
          timestamp: timestamp,
        ));
        widget.room.lastMessage = userMessage;
        widget.room.lastMessageTime = timestamp;
        controller.clear();
      });
      _sendMessage(userMessage);
      _scrollToBottom();
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

    final timestamp = DateTime.now();

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final apiResponse = data['choices'][0]['message']['content'];
      setState(() {
        widget.room.messages.add(Message(
          sender: 'Llama',
          content: apiResponse,
          timestamp: timestamp,
        ));
        widget.room.lastMessage = apiResponse;
        widget.room.lastMessageTime = timestamp;
      });
    } else {
      final errorMessage =
          'Llama: Failed to get response. Status: ${response.statusCode}';
      setState(() {
        widget.room.messages.add(Message(
          sender: 'Llama',
          content: errorMessage,
          timestamp: timestamp,
        ));
        widget.room.lastMessage = errorMessage;
        widget.room.lastMessageTime = timestamp;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
              controller: _scrollController,
              itemCount: widget.room.messages.length,
              itemBuilder: (context, index) {
                final message = widget.room.messages[index];
                final isUserMessage = message.sender == 'User';

                return Dismissible(
                  key: Key(message.content + index.toString()),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    setState(() {
                      widget.room.messages.removeAt(index);
                      if (widget.room.messages.isNotEmpty) {
                        final lastMessage = widget.room.messages.last;
                        widget.room.lastMessage = lastMessage.content;
                        widget.room.lastMessageTime = lastMessage.timestamp;
                      } else {
                        widget.room.lastMessage = '';
                        widget.room.lastMessageTime = null;
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message deleted')),
                    );
                  },
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return SimpleDialog(
                            children: [
                              ListTile(
                                title: const Text('Copy'),
                                onTap: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                              ListTile(
                                title: const Text('Share'),
                                onTap: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                              ListTile(
                                title: const Text('Delete message'),
                                onTap: () {
                                  setState(() {
                                    widget.room.messages.removeAt(index);
                                    if (widget.room.messages.isNotEmpty) {
                                      final lastMessage =
                                          widget.room.messages.last;
                                      widget.room.lastMessage =
                                          lastMessage.content;
                                      widget.room.lastMessageTime =
                                          lastMessage.timestamp;
                                    } else {
                                      widget.room.lastMessage = '';
                                      widget.room.lastMessageTime = null;
                                    }
                                  });
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Message deleted')),
                                  );
                                },
                              ),
                              ListTile(
                                title: const Text('Stick the message on top'),
                                onTap: () {
                                  setState(() {
                                    pinnedMessage = message.content;
                                  });
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                    onLongPress: () {
                      setState(() {
                        pinnedMessage = message.content;
                      });
                    },
                    child: Align(
                      alignment: isUserMessage
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        child: isUserMessage
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                                0.6,
                                      ),
                                      padding: const EdgeInsets.all(12.0),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent,
                                        borderRadius:
                                            BorderRadius.circular(16.0),
                                      ),
                                      child: Text(
                                        message.content,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('HH:mm')
                                        .format(message.timestamp),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: Colors.grey[300],
                                              child: const Icon(Icons.person,
                                                  color: Colors.white),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              widget.room.name,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.6,
                                          ),
                                          padding: const EdgeInsets.all(12.0),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            borderRadius:
                                                BorderRadius.circular(16.0),
                                          ),
                                          child: Text(
                                            message.content,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('HH:mm')
                                              .format(message.timestamp),
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
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
          ),
          Container(
            padding: const EdgeInsets.only(
                left: 8.0, right: 8.0, bottom: 8.0, top: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.0),
                        borderSide: BorderSide.none,
                      ),
                      fillColor: Colors.grey[200],
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 0.0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: IconButton(
                    onPressed: sendMessage,
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
