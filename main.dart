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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatting'),
        actions: const [
          IconButton(
            onPressed: null,
            icon: Icon(Icons.search),
          ),
          IconButton(
            onPressed: null,
            icon: Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            onPressed: null,
            icon: Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(),
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
