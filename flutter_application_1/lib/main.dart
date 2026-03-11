import 'package:flutter/material.dart';

void main() {
  runApp(const MySocialApp());
}

class MySocialApp extends StatelessWidget {
  const MySocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          "Instagram Clone", // ఇక్కడ మీ యాప్ పేరు ఇచ్చుకోవచ్చు
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.send_outlined, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 10, // ప్రస్తుతం 10 పోస్ట్‌లు చూపిద్దాం
        itemBuilder: (context, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. యూజర్ హెడర్ (User Header)
              const Padding(
                padding: EdgeInsets.all(10.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey,
                      radius: 18,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    SizedBox(width: 10),
                    Text("User_Name", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              // 2. పోస్ట్ ఇమేజ్ (Post Image)
              Container(
                height: 400,
                width: double.infinity,
                color: Colors.grey[300],
                child: const Icon(Icons.image, size: 80, color: Colors.white),
              ),
              // 3. లైక్ & కామెంట్ బటన్లు (Action Buttons)
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.chat_bubble_outline), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.send_outlined), onPressed: () {}),
                ],
              ),
              const Divider(), // పోస్ట్‌ల మధ్య లైన్
            ],
          );
        },
      ),
    );
  }
}