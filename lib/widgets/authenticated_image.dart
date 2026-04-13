import 'package:flutter/material.dart';
import '../services/image_service.dart';

String _normalizeImagePath(String imageUrl) {
  if (imageUrl.contains('https://pos.zevtabs.mn/api/file?path=') ||
      imageUrl.startsWith('baraa/')) {
    if (imageUrl.startsWith('baraa/')) {
      return 'baraa/${imageUrl.split('baraa/').last}';
    }
    return imageUrl.split('path=').last;
  }
  return imageUrl;
}

class AuthenticatedImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const AuthenticatedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
  });

  @override
  State<AuthenticatedImage> createState() => _AuthenticatedImageState();
}

class _AuthenticatedImageState extends State<AuthenticatedImage> {
  final ImageService _imageService = ImageService();
  late Future<ImageProvider> _providerFuture;

  @override
  void initState() {
    super.initState();
    _providerFuture =
        _imageService.getAuthenticatedImageProvider(_normalizeImagePath(widget.imageUrl));
  }

  @override
  void didUpdateWidget(AuthenticatedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _providerFuture =
          _imageService.getAuthenticatedImageProvider(_normalizeImagePath(widget.imageUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider>(
      future: _providerFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return RepaintBoundary(
            child: Image(
              image: snapshot.data!,
              width: widget.width,
              height: widget.height,
              fit: widget.fit ?? BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: widget.width,
                  height: widget.height,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: widget.width != null && widget.width! < 50 ? 20 : 32,
                      ),
                      if (widget.width == null || widget.width! >= 50)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'No Image',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        } else if (snapshot.hasError) {
          return Container(
            width: widget.width,
            height: widget.height,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: widget.width != null && widget.width! < 50 ? 20 : 32,
                ),
                if (widget.width == null || widget.width! >= 50)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Image Error',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
              ],
            ),
          );
        } else {
          return Container(
            width: widget.width,
            height: widget.height,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
      },
    );
  }
}
