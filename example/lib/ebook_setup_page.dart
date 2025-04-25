import 'package:flutter/material.dart';

import 'home_page.dart';

class EbookSetupPage extends StatelessWidget {
  EbookSetupPage({super.key});

  final tfUrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ebook Setup'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: tfUrl,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter ebook URL',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MyHomePage(
                      title: 'Epub Viewer Demo',
                      url: tfUrl.text,
                    ),
                  ),
                ),
                child: const Text('Load Ebook'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
