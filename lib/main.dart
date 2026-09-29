import 'package:flutter/material.dart';

import 'app_services.dart';
import 'home/library_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Services are created *after* the first frame, so a slow start (assets
  // manifest, preferences, database handle) never shows as a blank screen.
  runApp(const ComicReaderApp());
}

class ComicReaderApp extends StatefulWidget {
  const ComicReaderApp({super.key});

  @override
  State<ComicReaderApp> createState() => _ComicReaderAppState();
}

class _ComicReaderAppState extends State<ComicReaderApp> {
  final _startup = Stopwatch()..start();

  late final Future<AppServices> _services = _createServices();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('ComicsNow: first frame at ${_startup.elapsedMilliseconds}ms');
    });
  }

  Future<AppServices> _createServices() async {
    final services = await AppServices.create();
    // Useful when diagnosing a slow start: the first frame is already on
    // screen at this point, so the delay is visible rather than a blank page.
    debugPrint('ComicsNow: services ready at ${_startup.elapsedMilliseconds}ms');
    return services;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ComicsNow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: FutureBuilder<AppServices>(
        future: _services,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _StartupError(error: snapshot.error!);
          }

          final services = snapshot.data;
          if (services == null) {
            return const _StartupLoading();
          }

          return LibraryPage(services: services);
        },
      ),
    );
  }
}

class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              const Text(
                'Avvio non riuscito',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
