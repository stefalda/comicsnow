
import 'package:comicsnow/platform/open_with.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('comicsnow/open_with');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Lets the pending `initialize()` work (method calls, microtasks) settle.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// Simulates the platform pushing a file while the app is running.
  Future<void> push(String path) async {
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('open', path)),
      (_) {},
    );
    await settle();
  }

  setUp(() {
    OpenWith.resetForTesting();
    messenger.setMockMethodCallHandler(channel, null);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    OpenWith.resetForTesting();
  });

  test('a file received at startup and one pushed later both arrive', () async {
    // The library page subscribes *before* initializing, so nothing is lost.
    final received = <String>[];
    final subscription = OpenWith.incoming.listen(received.add);

    final asked = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      asked.add(call.method);
      return switch (call.method) {
        'takePending' => <String>['/tmp/avvio.cbz'],
        _ => null,
      };
    });

    await OpenWith.initialize();
    await settle();

    // Cold start: the file the system opened the app with.
    expect(received, ['/tmp/avvio.cbz']);
    // `ready` must come first, so a pushed file cannot arrive before the
    // handler is installed on the Dart side.
    expect(asked, ['ready', 'takePending']);

    // Warm start: the app is already running.
    await push('/tmp/dopo.cbz');
    expect(received, ['/tmp/avvio.cbz', '/tmp/dopo.cbz']);

    await subscription.cancel();
  });

  test('paths buffered before the listener arrives are not lost', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'takePending' => <String>['/tmp/presto.cbz'],
        _ => null,
      };
    });

    // No listener yet: the controller buffers.
    await OpenWith.initialize();
    await settle();

    final received = <String>[];
    final subscription = OpenWith.incoming.listen(received.add);
    await settle();

    expect(received, ['/tmp/presto.cbz']);
    await subscription.cancel();
  });

  test('an empty or malformed payload is ignored', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'takePending' => <Object?>['', '/tmp/buono.cbz', 42],
        _ => null,
      };
    });

    final received = <String>[];
    final subscription = OpenWith.incoming.listen(received.add);
    await OpenWith.initialize();
    await settle();

    await push('');
    await push('/tmp/altro.cbz');

    expect(received, ['/tmp/buono.cbz', '/tmp/altro.cbz']);
    await subscription.cancel();
  });

  // Windows and Linux have no such channel: the app must start anyway.
  test('without the platform channel nothing happens and nothing throws',
      () async {
    final received = <String>[];
    final subscription = OpenWith.incoming.listen(received.add);

    await OpenWith.initialize();
    await settle();

    expect(received, isEmpty);
    await subscription.cancel();
  });
}
