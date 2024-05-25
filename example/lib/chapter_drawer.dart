import 'package:epub_viewer/epub_viewer.dart';
import 'package:flutter/material.dart';

class ChapterDrawer extends StatefulWidget {
  const ChapterDrawer({super.key, required this.controller});

  final EpubController controller;

  @override
  State<ChapterDrawer> createState() => _ChapterDrawerState();
}

class _ChapterDrawerState extends State<ChapterDrawer> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: FutureBuilder(
            future: widget.controller.getChapters(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(snapshot.data![index].title),
                        onTap: () {
                          // widget.controller.jumpToChapter(snapshot.data![index]);
                          Navigator.pop(context);
                        },
                      );
                    });
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            }));
  }
}
