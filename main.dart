import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone data
  tzdata.initializeTimeZones();

  // Set the local timezone to 'Asia/Seoul'
  tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

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

class _MainRoomState extends State<MainRoom>
    with SingleTickerProviderStateMixin {
  final List<Room> chattingRooms = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _sortRooms();
      }
    });
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    await loadChatRooms();
  }

  Future<String> _getDocumentsDirectory() async {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  Future<void> loadChatRooms() async {
    try {
      final path = await _getDocumentsDirectory();
      final directory = Directory(path);
      final files = directory.listSync();

      setState(() {
        chattingRooms.clear();
        for (var file in files) {
          if (file is File &&
              file.path.endsWith('.json') &&
              file.path.contains('log_')) {
            String contents = file.readAsStringSync();
            Map<String, dynamic> jsonData = json.decode(contents);
            chattingRooms.add(Room.fromJson(jsonData));
          }
        }
      });
      print('Chat rooms loaded from $path');
    } catch (e) {
      print('Error loading chat rooms: $e');
    }
  }

  void addChattingRoom(String roomName) {
    setState(() {
      final newRoom =
          Room(name: roomName, id: tz.TZDateTime.now(tz.local).toString());
      chattingRooms.add(newRoom);
      _sortRooms();
    });
    saveChatRoom(chattingRooms.last);
  }

  Future<void> saveChatRoom(Room room) async {
    try {
      final path = await _getDocumentsDirectory();
      String sanitizedAgentName =
          room.name.replaceAll(RegExp(r'[<>:"\/\\|?*]'), '_');
      final file = File('$path/log_$sanitizedAgentName.json');
      Map<String, dynamic> jsonData = room.toJson();
      await file.writeAsString(json.encode(jsonData));
      print('Chat room saved to $path/log_$sanitizedAgentName.json');
    } catch (e) {
      print('Error saving chat room: $e');
    }
  }

  void chattingRoomDialog() {
    String roomName = '';
    TextEditingController controller = TextEditingController();
    bool isAgentNameValid = false;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool validateAgentName(String value) {
              RegExp regExp = RegExp(r'^[a-zA-Z0-9_]{1,10}$');
              return regExp.hasMatch(value);
            }

            return AlertDialog(
              title: const Text('Agent Name'),
              content: TextField(
                controller: controller,
                maxLines: 1,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                ],
                onChanged: (value) {
                  roomName = value;
                  setState(() {
                    isAgentNameValid = validateAgentName(value);
                  });
                },
                decoration:
                    const InputDecoration(hintText: 'Write down new name.'),
              ),
              actions: [
                TextButton(
                  onPressed: isAgentNameValid
                      ? () {
                          addChattingRoom(roomName);
                          Navigator.of(context).pop();
                        }
                      : null,
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
      },
    );
  }

  void _sortRooms() {
    setState(() {
      chattingRooms.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        if (_tabController.index == 0) {
          return a.name.compareTo(b.name);
        } else {
          return (b.lastMessageTime ?? tz.TZDateTime.now(tz.local))
              .compareTo(a.lastMessageTime ?? tz.TZDateTime.now(tz.local));
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatting',
            style: TextStyle(fontWeight: FontWeight.w500)),
        actions: [
          IconButton(
            onPressed: () {
              // 검색 기능 구현 또는 비워두기
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: chattingRoomDialog,
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            onPressed: () {
              // 설정 기능 구현 또는 비워두기
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.person),
              text: 'Sort by name',
            ),
            Tab(
              icon: Icon(Icons.chat_bubble_outline),
              text: 'Sort by date',
            ),
          ],
        ),
      ),
      body: chattingRooms.isEmpty
          ? const Center(child: Text('No chat rooms available.'))
          : ListView.builder(
              itemCount: chattingRooms.length,
              itemBuilder: (BuildContext context, int index) {
                final room = chattingRooms[index];

                final now = tz.TZDateTime.now(tz.local);
                String timeDisplay;
                if (room.lastMessageTime != null) {
                  final today =
                      tz.TZDateTime(tz.local, now.year, now.month, now.day);
                  final messageDate = tz.TZDateTime(
                      tz.local,
                      room.lastMessageTime!.year,
                      room.lastMessageTime!.month,
                      room.lastMessageTime!.day);
                  final difference = today.difference(messageDate).inDays;

                  if (difference == 0) {
                    timeDisplay =
                        DateFormat('HH:mm').format(room.lastMessageTime!);
                  } else if (difference == 1) {
                    timeDisplay = 'Yesterday';
                  } else {
                    timeDisplay =
                        DateFormat('MM/dd').format(room.lastMessageTime!);
                  }
                } else {
                  timeDisplay = '';
                }

                return ListTile(
                  leading: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircleAvatar(
                      backgroundColor: Colors.grey[300],
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                  ),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        room.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (room.messages.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Text(
                            '${room.messages.length}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Colors.grey[500],
                                ),
                          ),
                        ),
                      if (room.isPinned)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.push_pin,
                              size: 16, color: Colors.orange),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    room.lastMessage.isEmpty ? '' : room.lastMessage,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeDisplay,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      const SizedBox(height: 4),
                      if (room.messages.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${room.messages.length}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Colors.white,
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
                          title: Text(room.isPinned
                              ? 'Unstick on top'
                              : 'Stick on top'),
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
                                saveChatRoom(room);
                                Navigator.of(context).pop();
                              },
                              child: const Text('Yes'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
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
    );
  }
}

class Room {
  final String name;
  final String id;
  String lastMessage;
  tz.TZDateTime? lastMessageTime;
  bool isPinned;
  List<Message> messages;

  Room({
    required this.name,
    required this.id,
    this.lastMessage = '',
    this.isPinned = false,
    tz.TZDateTime? lastMessageTime,
    List<Message>? messages,
  })  : lastMessageTime = lastMessageTime ?? tz.TZDateTime.now(tz.local),
        messages = messages ?? [];

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'isPinned': isPinned,
      'messages': messages.map((msg) => msg.toJson()).toList(),
    };
  }

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      name: json['name'],
      id: json['id'],
      lastMessage: json['lastMessage'],
      lastMessageTime: json['lastMessageTime'] != null
          ? tz.TZDateTime.parse(tz.local, json['lastMessageTime'])
          : null,
      isPinned: json['isPinned'] ?? false,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((msgJson) => Message.fromJson(msgJson))
              .toList() ??
          [],
    );
  }
}

class Message {
  final String sender;
  final String content;
  final tz.TZDateTime timestamp;

  Message({
    required this.sender,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'sender': sender,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      sender: json['sender'],
      content: json['content'],
      timestamp: tz.TZDateTime.parse(tz.local, json['timestamp']),
    );
  }
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
  bool isButtonEnabled = false;
  bool _isLoading = false;
  bool isPinnedMessageExpanded = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      setState(() {
        isButtonEnabled = controller.text.length >= 20;
      });
    });
  }

  Future<String> _getDocumentsDirectory() async {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  Future<void> saveChatRoom() async {
    try {
      final path = await _getDocumentsDirectory();
      String sanitizedAgentName =
          widget.room.name.replaceAll(RegExp(r'[<>:"\/\\|?*]'), '_');
      final file = File('$path/log_$sanitizedAgentName.json');
      Map<String, dynamic> jsonData = widget.room.toJson();
      await file.writeAsString(json.encode(jsonData));
      print('Chat room saved to $path/log_$sanitizedAgentName.json');
    } catch (e) {
      print('Error saving chat room: $e');
    }
  }

  List<Map<String, String>> getMessagesForApi() {
    return widget.room.messages.map((message) {
      return {
        'role': message.sender == 'User' ? 'user' : 'assistant',
        'content': message.content,
      };
    }).toList();
  }

  void sendMessage() {
    if (controller.text.isNotEmpty && controller.text.length >= 20) {
      final userMessage = controller.text;
      final timestamp = tz.TZDateTime.now(tz.local);
      setState(() {
        widget.room.messages.add(Message(
          sender: 'User',
          content: userMessage,
          timestamp: timestamp,
        ));
        widget.room.lastMessage = userMessage;
        widget.room.lastMessageTime = timestamp;
        controller.clear();
        isButtonEnabled = false;
        _isLoading = true;
      });
      saveChatRoom();
      _sendMessage(userMessage).then((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage(String message) async {
    List<Map<String, String>> messagesForApi = getMessagesForApi();

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer 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', // Replace with your API key
        },
        body: json.encode({
          'model': 'llama3-8b-8192',
          'messages': messagesForApi,
        }),
      );

      final timestamp = tz.TZDateTime.now(tz.local);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final apiResponse = data['choices'][0]['message']['content'];
        if (!mounted) return;
        setState(() {
          widget.room.messages.add(Message(
            sender: 'Assistant',
            content: apiResponse,
            timestamp: timestamp,
          ));
          widget.room.lastMessage = apiResponse;
          widget.room.lastMessageTime = timestamp;
        });
        saveChatRoom();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get response from server.')),
        );
      }
      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred.')),
      );
      setState(() {
        _isLoading = false;
      });
    }
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

  bool isPinnedMessageMultiLine() {
    final span = TextSpan(
      text: pinnedMessage!,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );

    final tp = TextPainter(
      text: span,
      maxLines: 1,
      textDirection: Directionality.of(context),
    );

    tp.layout(maxWidth: MediaQuery.of(context).size.width - 100);

    return tp.didExceedMaxLines;
  }

  @override
  void dispose() {
    controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget buildAssistantMessage(Message message) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end, // 아래쪽 정렬
      children: [
        CircleAvatar(
          backgroundColor: Colors.grey[300],
          child: const Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.6,
                ),
                padding: const EdgeInsets.all(12.0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(
                  message.content,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          DateFormat('HH:mm').format(message.timestamp),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey,
              ),
        ),
      ],
    );
  }

  Widget buildUserMessage(Message message) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end, // 아래쪽 정렬
      children: [
        Text(
          DateFormat('HH:mm').format(message.timestamp),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.6,
                ),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.yellow[600],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(
                  message.content,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[200],
      appBar: AppBar(
        title: Text(widget.room.name),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_isLoading) const LinearProgressIndicator(),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    top: pinnedMessage != null ? 60.0 : 0.0,
                  ),
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
                        saveChatRoom();
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
                            barrierDismissible: false,
                            context: context,
                            builder: (BuildContext context) {
                              return SimpleDialog(
                                children: [
                                  ListTile(
                                    title: const Text('Copy'),
                                    onTap: () {
                                      Clipboard.setData(
                                          ClipboardData(text: message.content));
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  ListTile(
                                    title: const Text('Share'),
                                    onTap: () {
                                      // 공유 기능 구현
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
                                      saveChatRoom();
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('Message deleted')),
                                      );
                                    },
                                  ),
                                  ListTile(
                                    title:
                                        const Text('Stick the message on top'),
                                    onTap: () {
                                      setState(() {
                                        pinnedMessage = message.content;
                                        isPinnedMessageExpanded = false;
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
                            isPinnedMessageExpanded = false;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 4.0),
                          child: isUserMessage
                              ? buildUserMessage(message)
                              : buildAssistantMessage(message),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.only(
                    left: 8.0, right: 8.0, bottom: 8.0, top: 4.0),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IconButton(
                        onPressed: () {
                          // 기능 구현
                        },
                        icon: const Icon(Icons.add),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 150.0,
                          ),
                          child: Scrollbar(
                            child: TextField(
                              controller: controller,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              decoration: InputDecoration(
                                hintText: 'Input message here',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24.0),
                                  borderSide: BorderSide.none,
                                ),
                                fillColor: Colors.grey[200],
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 12.0),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          // 기능 구현
                        },
                        icon: const Icon(Icons.tag_faces),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.yellow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: isButtonEnabled && !_isLoading
                              ? sendMessage
                              : null,
                          icon: const Icon(Icons.send),
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (pinnedMessage != null)
            Positioned(
              top: _isLoading ? 4.0 : 0.0,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Stack(
                  children: [
                    // Main container
                    Container(
                      padding: const EdgeInsets.only(
                          left: 40.0, right: 8.0, top: 12.0, bottom: 12.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Message area
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (isPinnedMessageMultiLine()) {
                                  setState(() {
                                    isPinnedMessageExpanded =
                                        !isPinnedMessageExpanded;
                                  });
                                }
                              },
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: isPinnedMessageExpanded
                                      ? MediaQuery.of(context).size.height * 0.5
                                      : 40.0,
                                ),
                                child: SingleChildScrollView(
                                  child: Text(
                                    pinnedMessage!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Arrow icon
                          if (isPinnedMessageMultiLine())
                            IconButton(
                              icon: Icon(
                                isPinnedMessageExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                              ),
                              onPressed: () {
                                setState(() {
                                  isPinnedMessageExpanded =
                                      !isPinnedMessageExpanded;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    // Left-positioned blue megaphone icon
                    const Positioned(
                      left: 8.0,
                      top: 12.0,
                      child: Icon(
                        Icons.campaign,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
