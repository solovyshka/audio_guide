import 'package:flutter/material.dart';

import '../models/guide.dart';

class GuideTextScreen extends StatelessWidget {
  const GuideTextScreen({super.key, required this.guide});

  final Guide guide;

  @override
  Widget build(BuildContext context) {
    final items = guide.playlist;
    return Scaffold(
      appBar: AppBar(title: Text(guide.title)),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 28),
        itemBuilder: (context, index) {
          final track = items[index];
          final heading = index == 0 ? 'Вступление' : '$index. ${track.title}';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF1F4B3A),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                track.text.isEmpty ? 'Текста пока нет' : track.text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}
