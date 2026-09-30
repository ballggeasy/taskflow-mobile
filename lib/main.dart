import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Task {
  Task({required this.id, required this.title, required this.done});

  factory Task.fromJson(Map<String, dynamic> json) =>
      Task(id: json['id'] as int, title: json['title'] as String, done: json['done'] as bool);

  final int id;
  final String title;
  final bool done;
}

/// Loads tasks from the taskflow-api backend.
class TaskApi {
  TaskApi({http.Client? client, this.baseUrl = 'http://10.0.2.2:8080'})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<List<Task>> fetchTasks() async {
    final res = await _client.get(Uri.parse('$baseUrl/tasks'));
    if (res.statusCode != 200) {
      throw Exception('GET /tasks failed: ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }
}

void main() => runApp(TaskflowApp(api: TaskApi()));

class TaskflowApp extends StatelessWidget {
  const TaskflowApp({super.key, required this.api});

  final TaskApi api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taskflow',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: TaskListPage(api: api),
    );
  }
}

class TaskListPage extends StatelessWidget {
  const TaskListPage({super.key, required this.api});

  final TaskApi api;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Taskflow')),
      body: FutureBuilder<List<Task>>(
        future: api.fetchTasks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load tasks: ${snapshot.error}'));
          }
          final tasks = snapshot.data!;
          if (tasks.isEmpty) return const Center(child: Text('No tasks yet'));
          return ListView(
            children: [
              for (final t in tasks)
                ListTile(
                  leading: Icon(t.done ? Icons.check_circle : Icons.radio_button_unchecked),
                  title: Text(t.title),
                ),
            ],
          );
        },
      ),
    );
  }
}
