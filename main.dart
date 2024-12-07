import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:shared_preferences/shared_preferences.dart';

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
    await loadRoomList();
    await _loadPinnedStatesFromPrefs();
    _sortRooms();
  }

  Future<String> _getDocumentsDirectory() async {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  // ---------------------------
  // Load and Save Room List
  // ---------------------------
  Future<void> loadRoomList() async {
    try {
      final path = await _getDocumentsDirectory();
      final file = File('$path/chatlog.json');
      if (file.existsSync()) {
        String contents = file.readAsStringSync();
        List<dynamic> jsonData = json.decode(contents);
        setState(() {
          chattingRooms.clear();
          for (var roomJson in jsonData) {
            chattingRooms.add(Room.fromJsonForRoomList(roomJson));
          }
        });
        print('Room list loaded from $path/chatlog.json');
      } else {
        setState(() {
          chattingRooms.clear();
        });
      }
    } catch (e) {
      print('Error loading room list: $e');
      setState(() {
        chattingRooms.clear();
      });
    }
  }

  Future<void> saveRoomList() async {
    try {
      final path = await _getDocumentsDirectory();
      final file = File('$path/chatlog.json');
      List<Map<String, dynamic>> jsonData =
          chattingRooms.map((room) => room.toJsonForRoomList()).toList();
      await file.writeAsString(json.encode(jsonData));
      print('Room list saved to $path/chatlog.json');
    } catch (e) {
      print('Error saving room list: $e');
    }
  }

  // ---------------------------
  // SharedPreferences로부터 핀 상태 로딩/저장
  // ---------------------------
  Future<void> _loadPinnedStatesFromPrefs() async {
    // 35페이지, 앱을 켤때 채팅방의 pin 상태 가져옴
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? pinnedRoomIds = prefs.getStringList('pinned_rooms');
    if (pinnedRoomIds != null && pinnedRoomIds.isNotEmpty) {
      for (var room in chattingRooms) {
        if (pinnedRoomIds.contains(room.id)) {
          room.isPinned = true;
        } else {
          room.isPinned = false;
        }
      }
    } else {
      // SharedPreferences에 pinned_rooms 정보가 없으면,
      // 파일에서 불러온 isPinned 값 그대로 사용
    }
  }

  Future<void> _savePinnedStatesToPrefs() async {
    // 35페이지, 채팅방 자체는 chatlog에 저장하지만 채팅방의 pin 여부는 SharedPreferences를 이용하여 따로 저장해둠
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> pinnedRoomIds =
        chattingRooms.where((room) => room.isPinned).map((r) => r.id).toList();
    await prefs.setStringList('pinned_rooms', pinnedRoomIds);
  }

  // ---------------------------
  // 채팅방 생성 시 빈 log_agentname.json 파일도 바로 생성
  // ---------------------------
  Future<void> _createEmptyChatLog(Room room) async {
    // 32페이지, 채팅방이 생성되면 바로 log_agentname.json 파일이 생성되게 함
    try {
      final path = await _getDocumentsDirectory();
      String sanitizedAgentName =
          room.name.replaceAll(RegExp(r'[<>:"\/\\|?*]'), '_');
      final file = File('$path/log_$sanitizedAgentName.json');
      if (!file.existsSync()) {
        // pinnedMessage와 messages가 비어있는 초기 상태
        Map<String, dynamic> dataToSave = {
          'pinnedMessage': null,
          'messages': [],
        };
        await file.writeAsString(json.encode(dataToSave));
        print(
            'Empty chat log created for ${room.name} at $path/log_$sanitizedAgentName.json');
      }
    } catch (e) {
      print('Error creating empty chat log for ${room.name}: $e');
    }
  }

  // ---------------------------
  // Add Room
  // ---------------------------
  void addChattingRoom(String roomName) async {
    setState(() {
      final newRoom = Room(
        name: roomName,
        id: tz.TZDateTime.now(tz.local).toString(),
      );
      chattingRooms.add(newRoom);
      _sortRooms();
    });
    saveRoomList();
    _savePinnedStatesToPrefs();

    final newRoom = chattingRooms.last;
    await _createEmptyChatLog(
        newRoom); // 32페이지, 채팅방 생성 시 바로 log_agentname.json 파일 생성
  }

  void chattingRoomDialog() {
    String roomName = '';
    TextEditingController controller = TextEditingController();
    bool isAgentNameValid = false;

    showDialog(
      barrierDismissible: false, // 31페이지, dialog 바깥 눌러도 꺼지지않음
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool validateAgentName(String value) {
              RegExp regExp = RegExp(
                  r'^[a-zA-Z0-9_]{1,10}$'); // 30페이지, 최종 검증 때 문자열 길이와 빈칸 확인
              return regExp.hasMatch(value);
            }

            return AlertDialog(
              // 29페이지
              title: const Text('Agent Name'),
              content: TextFormField(
                // 29페이지
                controller: controller,
                maxLines: 1, //30페이지, mulit-line 방지
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-Z0-9_]')), // 30페이지, 입력시 알파벳, 정수, 아래바만 허용
                ],
                onChanged: (value) {
                  roomName = value;
                  setState(() {
                    isAgentNameValid = validateAgentName(value);
                  });
                },
                decoration: const InputDecoration(
                    hintText: 'Write down new name.'), // 30페이지, placeholder 구현
              ),
              actions: [
                TextButton(
                  // 29페이지
                  onPressed: isAgentNameValid
                      ? () {
                          addChattingRoom(roomName);
                          Navigator.of(context).pop();
                        }
                      : null,
                  child: const Text('Apply'), // 31페이지
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'), // 31페이지
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

  void _togglePin(Room room) {
    setState(() {
      room.isPinned = !room.isPinned;
      _sortRooms();
    });
    saveRoomList();
    _savePinnedStatesToPrefs();
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
              // 검색 기능 (미구현)
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: chattingRoomDialog,
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            onPressed: () {
              // 설정 기능 (미구현)
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
                    // 34페이지, barrierDismissible을 false로 설정하지 않음으로써 default값인 true를 반환함. 바깥을 누르면 dialog가 종료됨.
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          // 33페이지
                          title: Text(room.isPinned // 33페이지
                              ? 'Unstick on top'
                              : 'Stick on top'),
                          content: Text(room.isPinned
                              ? "Do you want to unput '${room.name}' on the top of the list?"
                              : "Do you want to put '${room.name}' on the top of the list?"),
                          actions: [
                            TextButton(
                              // 33페이지
                              onPressed: () {
                                _togglePin(room);
                                Navigator.of(context).pop();
                              },
                              child: const Text('Yes'), // 34페이지
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('No'), // 34페이지
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

  Map<String, dynamic> toJsonForRoomList() {
    return {
      'name': name,
      'id': id,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'isPinned': isPinned,
    };
  }

  factory Room.fromJsonForRoomList(Map<String, dynamic> json) {
    return Room(
      name: json['name'],
      id: json['id'],
      lastMessage: json['lastMessage'] ?? '',
      lastMessageTime: json['lastMessageTime'] != null
          ? tz.TZDateTime.parse(tz.local, json['lastMessageTime'])
          : null,
      isPinned: json['isPinned'] ?? false,
      messages: [],
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
  String? pinnedMessage; // 27페이지, pinned된 메시지가 채팅방 개별 json파일에 같이 저장되고 불러와짐
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
    _loadChatLog();
  }

  Future<String> _getDocumentsDirectory() async {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  Future<void> _loadChatLog() async {
    try {
      final path = await _getDocumentsDirectory();
      String sanitizedAgentName =
          widget.room.name.replaceAll(RegExp(r'[<>:"\/\\|?*]'), '_');
      final file = File('$path/log_$sanitizedAgentName.json'); // 25페이지
      if (file.existsSync()) {
        String contents = file.readAsStringSync();
        // ---------------------- 여기서 pinnedMessage 로딩 추가 ----------------------
        // 기존에는 단순히 List<dynamic>로 메시지만 불러왔지만, 이제는 pinnedMessage도 포함한 object를 불러옴.
        Map<String, dynamic> data = json.decode(contents);
        List<dynamic> jsonMessages = data['messages'] ?? [];
        String? loadedPinnedMessage =
            data['pinnedMessage']; // 27페이지, pinned된 채팅 불러오기
        // ------------------------------------------------------------------------
        setState(() {
          widget.room.messages.clear();
          for (var msgJson in jsonMessages) {
            widget.room.messages.add(Message.fromJson(msgJson));
          }
          if (widget.room.messages.isNotEmpty) {
            final lastMessage = widget.room.messages.last;
            widget.room.lastMessage = lastMessage.content;
            widget.room.lastMessageTime = lastMessage.timestamp;
          } else {
            widget.room.lastMessage = '';
            widget.room.lastMessageTime = null;
          }
          pinnedMessage = loadedPinnedMessage; // 27페이지, pinned 메시지 로딩
        });
        print('Chat log loaded from $path/log_$sanitizedAgentName.json');
      }
    } catch (e) {
      print('Error loading chat log: $e');
    }
  }

  Future<void> _saveChatLog() async {
    try {
      final path = await _getDocumentsDirectory();
      String sanitizedAgentName =
          widget.room.name.replaceAll(RegExp(r'[<>:"\/\\|?*]'), '_');
      final file = File('$path/log_$sanitizedAgentName.json'); // 25페이지
      List<Map<String, dynamic>> jsonData =
          widget.room.messages.map((msg) => msg.toJson()).toList();

      // ---------------------- 여기서 pinnedMessage 저장 추가 ----------------------
      Map<String, dynamic> dataToSave = {
        'pinnedMessage': pinnedMessage, // 27페이지, pinned 메시지 저장
        'messages': jsonData,
      };
      // --------------------------------------------------------------------------

      await file.writeAsString(json.encode(dataToSave));
      print('Chat log saved to $path/log_$sanitizedAgentName.json');
    } catch (e) {
      print('Error saving chat log: $e');
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
      _saveChatLog(); // 26페이지, 내 메시지 보낼때
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
    // 28페이지
    List<Map<String, String>> messagesForApi = getMessagesForApi();

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer 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',
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
        _saveChatLog(); // 26페이지, 상대방 메시지 도착했을때
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
    if (pinnedMessage == null) return false;
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

  // --------------------------
  // 수정된 부분 (Assistant 메시지)
  // --------------------------
  Widget buildAssistantMessage(Message message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // 전체를 위 기준으로 정렬
        children: [
          // 아이콘을 상단에 배치
          CircleAvatar(
            backgroundColor: Colors.grey[300],
            child: const Icon(Icons.person, color: Colors.white), // 20페이지
          ),
          const SizedBox(width: 8),

          // 이름과 (말풍선+시간)을 수직으로 배치
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이름을 말풍선 위에 표시
                Text(
                  widget.room.name, // 20페이지
                  style: const TextStyle(
                    // 23페이지
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),

                // 말풍선과 시간을 같은 Row에 배치하고 하단 정렬
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.6, // 최대 너비
                        ),
                        padding: const EdgeInsets.all(12.0),
                        decoration: const BoxDecoration(
                          color: Colors.white, // 23페이지
                          borderRadius: BorderRadius.only(
                            // 23페이지
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          message.content, // 20페이지
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 시간을 말풍선 하단에 맞춤
                    Text(
                      DateFormat('HH:mm')
                          .format(message.timestamp), // 20페이지, 시간이 24시간 단위
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildUserMessage(Message message) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          DateFormat('HH:mm').format(message.timestamp), // 21페이지, 시간이 24시간 단위
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                // 23페이지
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
                  color: Colors.yellow[600], // 23페이지
                  borderRadius: const BorderRadius.only(
                    // 23페이지
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(
                  message.content, // 21페이지
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
      backgroundColor: Colors.blue[200], // 24페이지
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
                  padding: EdgeInsets.zero, // 18페이지, 공지가 채팅 위에 그대로 덮어쓰게 함
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
                        _saveChatLog(); // 26페이지, 왼쪽으로 밀어 메시지 삭제했을때
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
                                // 36페이지
                                children: [
                                  ListTile(
                                    // 36페이지
                                    title: const Text('Copy'), // 36페이지
                                    onTap: () {
                                      Clipboard.setData(
                                          ClipboardData(text: message.content));
                                      Navigator.of(context).pop(); // 37페이지, 닫기
                                    },
                                  ),
                                  ListTile(
                                    // 36페이지
                                    title: const Text('Share'), // 36페이지
                                    onTap: () {
                                      // 공유 기능 (미구현)
                                      Navigator.of(context).pop(); // 37페이지, 닫기
                                    },
                                  ),
                                  ListTile(
                                    // 36페이지
                                    title:
                                        const Text('Delete message'), // 36페이지
                                    onTap: () {
                                      setState(() {
                                        // 38페에지, 메시지삭제
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
                                      _saveChatLog(); // 26페이지, dialog에서 메시지 삭제됐을때
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('Message deleted')),
                                      );
                                    },
                                  ),
                                  ListTile(
                                    // 36페이지
                                    title: const Text(
                                        'Stick the message on top'), // 36페이지
                                    onTap: () {
                                      // 38페이지, 메시지고정
                                      setState(() {
                                        pinnedMessage = message.content;
                                        isPinnedMessageExpanded = false;
                                      });
                                      _saveChatLog(); // pinned message 변경시에도 저장
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
                          _saveChatLog(); // pinned message 변경시에도 저장
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
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch, // 19페이지, 칸이 길어지면 버튼도 길어지게함
                    children: [
                      IconButton(
                        onPressed: () {
                          // 기능 구현 (미구현)
                        },
                        icon: const Icon(Icons.add),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        // 19페이지, 세 개의 아이콘을 제외하고 메시지가 입력되게함
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            // 19페이지, input box가 길어져도 스크롤로 가독성 유지함 (너무 길어지면 화면 위로 올라가 오류가 나기 때문에 길이 제한함)
                            maxHeight: 150.0,
                          ),
                          child: Scrollbar(
                            child: TextField(
                              controller: controller,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              decoration: const InputDecoration(
                                hintText: 'Input message here',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                  borderSide: BorderSide.none,
                                ),
                                fillColor: Colors.white, // 24페이지
                                filled: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 12.0),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          // 기능 구현 (미구현)
                        },
                        icon: const Icon(Icons.tag_faces),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.yellow, // 24페이지
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: isButtonEnabled && !_isLoading
                              ? sendMessage
                              : null,
                          icon: const Icon(Icons.send),
                          color: Colors.black,
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
              top: 10.0, // 18페이지
              left: 5.0, // 18페이지
              right: 5.0, // 18페이지
              child: Container(
                padding: const EdgeInsets.only(
                    left: 40.0, right: 8.0, top: 12.0, bottom: 12.0),
                decoration: BoxDecoration(
                  color: Colors.white, // 22페이지
                  borderRadius: BorderRadius.circular(10), // 22페이지
                ),
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
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
                                  style: Theme.of(context) // 22페이지
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        ),
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
                    const Positioned(
                      left: -32.0,
                      top: 0.0,
                      bottom: 0.0,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          Icons.campaign,
                          color: Colors.blue,
                        ),
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
