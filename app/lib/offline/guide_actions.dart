import 'package:flutter/material.dart';

import '../api/client.dart';
import '../models/guide.dart';
import '../screens/guide_text_screen.dart';
import 'guide_cache.dart';

enum GuideMenuAction { showText, download, delete }

List<PopupMenuEntry<GuideMenuAction>> buildGuideMenuItems(GuideSummary guide) {
  final cache = GuideCache.instance;
  final downloaded = cache.isDownloaded(guide.id);
  final local = cache.localVersion(guide.id);
  final outdated = downloaded && local != null && local != guide.contentVersion;
  return [
    const PopupMenuItem(
      value: GuideMenuAction.showText,
      child: Text('Показать текст'),
    ),
    if (!downloaded || outdated)
      PopupMenuItem(
        value: GuideMenuAction.download,
        child: Text(outdated ? 'Обновить' : 'Скачать'),
      ),
    if (downloaded && !outdated)
      const PopupMenuItem(
        value: GuideMenuAction.download,
        child: Text('Скачать заново'),
      ),
    if (downloaded)
      const PopupMenuItem(
        value: GuideMenuAction.delete,
        child: Text('Удалить загрузку'),
      ),
  ];
}

Future<void> handleGuideMenu({
  required BuildContext context,
  required GuideApi api,
  required GuideSummary guide,
  required GuideMenuAction action,
  Guide? loaded,
}) async {
  switch (action) {
    case GuideMenuAction.showText:
      await openGuideText(context, api, guide, loaded: loaded);
    case GuideMenuAction.download:
      await downloadGuide(context, api, guide);
    case GuideMenuAction.delete:
      await deleteDownloadedGuide(context, guide);
  }
}

Future<void> openGuideText(
  BuildContext context,
  GuideApi api,
  GuideSummary summary, {
  Guide? loaded,
}) async {
  Guide? guide = loaded;
  if (guide == null) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      try {
        guide = await api.getGuide(summary.id);
      } catch (_) {
        guide = await GuideCache.instance.loadLocal(summary.id);
      }
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }
  if (!context.mounted) {
    return;
  }
  if (guide == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось загрузить текст гида')),
    );
    return;
  }
  final opened = guide;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => GuideTextScreen(guide: opened),
    ),
  );
}

Future<void> downloadGuide(
  BuildContext context,
  GuideApi api,
  GuideSummary guide,
) async {
  final cache = GuideCache.instance;
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return ListenableBuilder(
        listenable: cache,
        builder: (context, _) {
          final progress = cache.progressOf(guide.id);
          return AlertDialog(
            title: const Text('Скачивание'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guide.title),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: progress?.fraction),
                const SizedBox(height: 8),
                Text(
                  progress == null
                      ? 'Подготовка…'
                      : '${progress.completed} из ${progress.total}'
                          '${progress.label == null ? '' : ' · ${progress.label}'}',
                ),
              ],
            ),
          );
        },
      );
    },
  );
  try {
    await cache.download(api, guide.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«${guide.title}» сохранён на телефоне')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось скачать: $error')),
      );
    }
  } finally {
    navigator.pop();
  }
}

Future<void> deleteDownloadedGuide(
  BuildContext context,
  GuideSummary guide,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Удалить загрузку?'),
        content: Text(
          '«${guide.title}» останется в каталоге, но аудио придётся слушать онлайн.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      );
    },
  );
  if (confirmed != true) {
    return;
  }
  await GuideCache.instance.delete(guide.id);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Загрузка «${guide.title}» удалена')),
    );
  }
}
