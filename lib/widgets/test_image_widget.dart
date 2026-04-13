import 'package:flutter/material.dart';
import '../services/image_service.dart';

class TestImageWidget extends StatefulWidget {
  const TestImageWidget({super.key});

  @override
  State<TestImageWidget> createState() => _TestImageWidgetState();
}

class _TestImageWidgetState extends State<TestImageWidget> {
  final ImageService _imageService = ImageService();
  String testImagePath =
      'baraa/1773899662788-51003529-.jpg'; // Known working image with baraa/ prefix
  String failingImagePath =
      'baraa/1773900011510-463759943-.jpg'; // Known failing image with baraa/ prefix

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Testing Image Service',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            // Test known working image
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text('Known Working Image:',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text(testImagePath, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 10),
                  FutureBuilder(
                    future: _imageService
                        .getAuthenticatedImageProvider(testImagePath),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Container(
                          width: 100,
                          height: 100,
                          color: Colors.green[100],
                          child: const Icon(Icons.check, color: Colors.white),
                        );
                      } else if (snapshot.hasError) {
                        return Container(
                          width: 100,
                          height: 100,
                          color: Colors.red[100],
                          child: const Icon(Icons.error, color: Colors.white),
                        );
                      } else {
                        return Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[300],
                          child: const CircularProgressIndicator(
                              color: Colors.white),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Test failing image
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text('Failing Image (500 Error):',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text(failingImagePath, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 10),
                  FutureBuilder(
                    future: _imageService
                        .getAuthenticatedImageProvider(failingImagePath),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Container(
                          width: 100,
                          height: 100,
                          color: Colors.green[100],
                          child: const Icon(Icons.check, color: Colors.white),
                        );
                      } else if (snapshot.hasError) {
                        return Container(
                          width: 100,
                          height: 100,
                          color: Colors.red[100],
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error, color: Colors.white),
                              const SizedBox(height: 4),
                              const Text(
                                '500 Error',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                            ],
                          ),
                        );
                      } else {
                        return Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[300],
                          child: const CircularProgressIndicator(
                              color: Colors.white),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
