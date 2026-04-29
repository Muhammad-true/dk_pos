import 'package:flutter/material.dart';

/// Общий блок загрузки медиа для video_bg (TV2/TV4).
class TvVideoBgMediaEditor extends StatelessWidget {
  const TvVideoBgMediaEditor({
    super.key,
    required this.title,
    this.videoHint,
    required this.videoPath,
    required this.videoEmptyText,
    required this.pickVideoText,
    required this.clearVideoText,
    required this.imageTitle,
    this.imageHint,
    required this.imagePath,
    required this.imageEmptyText,
    required this.pickImageText,
    required this.clearImageText,
    required this.uploading,
    required this.onPickVideo,
    this.onClearVideo,
    required this.onPickImage,
    this.onClearImage,
  });

  final String title;
  final String? videoHint;
  final String videoPath;
  final String videoEmptyText;
  final String pickVideoText;
  final String clearVideoText;

  final String imageTitle;
  final String? imageHint;
  final String imagePath;
  final String imageEmptyText;
  final String pickImageText;
  final String clearImageText;

  final bool uploading;
  final VoidCallback onPickVideo;
  final VoidCallback? onClearVideo;
  final VoidCallback onPickImage;
  final VoidCallback? onClearImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        if ((videoHint ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            videoHint!.trim(),
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          videoPath.isEmpty ? videoEmptyText : videoPath,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: uploading ? null : onPickVideo,
                icon: uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.video_file_rounded),
                label: Text(pickVideoText),
              ),
            ),
            if (videoPath.isNotEmpty) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: uploading ? null : onClearVideo,
                child: Text(clearVideoText),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Text(imageTitle, style: theme.textTheme.titleSmall),
        if ((imageHint ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            imageHint!.trim(),
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          imagePath.isEmpty ? imageEmptyText : imagePath,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: uploading ? null : onPickImage,
                icon: const Icon(Icons.image_rounded),
                label: Text(pickImageText),
              ),
            ),
            if (imagePath.isNotEmpty) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: uploading ? null : onClearImage,
                child: Text(clearImageText),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
