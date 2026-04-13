import 'package:flutter/material.dart';
import '../services/image_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider>(
      future: _imageService.getAuthenticatedImageProvider(
        widget.imageUrl.contains('https://pos.zevtabs.mn/api/file?path=') ||
                widget.imageUrl.startsWith('baraa/')
            ? widget.imageUrl.startsWith('baraa/')
                ? 'baraa/' + widget.imageUrl.split('baraa/').last
                : widget.imageUrl.split('path=').last
            : widget.imageUrl,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image(
            image: snapshot.data!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit ?? BoxFit.cover,
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
              child: CircularProgressIndicator(),
            ),
          );
        }
      },
    );
  }
}
