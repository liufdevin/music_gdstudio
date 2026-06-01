import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_gdstudio/main.dart';

void main() {
  testWidgets('shows the music search home page', (tester) async {
    await tester.pumpWidget(
      MusicGdStudioApp(audioHandler: _FakeAudioHandler()),
    );
    await tester.pump();

    expect(find.text('LF Music'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('音乐源'), findsOneWidget);
  });
}

class _FakeAudioHandler extends BaseAudioHandler {}
