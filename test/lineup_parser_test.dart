import 'package:flutter_test/flutter_test.dart';
import 'package:nightsuntv/data/services/lineup_refresh_service.dart';

void main() {
  test('parses attributes, alternative transport and deduplicates URLs', () {
    const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="BBCNews.uk" tvg-name="BBC News" tvg-logo="https://x/bbc.png",BBC News HD
#EXTVLCOPT:http-user-agent=TestAgent
#EXTVLCOPT:http-referrer="https://example.com/"
https://a.example/bbc.m3u8
https://a.example/bbc.m3u8
#EXTINF:-1 tvg-id="Foo.us" tvg-name="Foo",Foo 720p
#KODIPROP:inputstream.adaptive.stream_headers=User-Agent=Test%20Agent&Referer=https%3A%2F%2Fexample.org%2F
https://b.example/foo.m3u8
#EXTINF:-1 tvg-id="Unknown.xx" tvg-name="Unknown",Unknown
https://c.example/unknown.m3u8
#EXTINF:-1 tvg-id="Offline.uk",Offline
not-a-valid-url
''';

    final parsed = parseM3uLineup(
      playlist,
      knownChannelIds: {'BBCNews.uk', 'Foo.us', 'Offline.uk'},
    );

    expect(parsed.sources.keys, containsAll(['BBCNews.uk', 'Foo.us']));
    expect(parsed.sources['BBCNews.uk'], hasLength(1));
    expect(parsed.unknownChannels, 1);

    final bbc = parsed.sources['BBCNews.uk']!.single;
    expect(bbc.quality, isNull);
    expect(bbc.userAgent, 'TestAgent');
    expect(bbc.referrer, 'https://example.com/');
    expect(bbc.title, 'BBC News HD');

    final foo = parsed.sources['Foo.us']!.single;
    expect(foo.userAgent, contains('Test Agent'));
    expect(foo.referrer, 'https://example.org/');
    expect(foo.quality, '720p');
    expect(parsed.sources['Offline.uk'], isNull);
  });

  test('preserves 4K quality and limits mirrors per channel', () {
    final buffer = StringBuffer('#EXTM3U\n');
    for (var i = 0; i < 20; i++) {
      buffer.writeln('#EXTINF:-1 tvg-id="Big.uk",Big Channel 4K');
      buffer.writeln('https://cdn.example/$i.m3u8');
    }
    final parsed = parseM3uLineup(
      buffer.toString(),
      knownChannelIds: {'Big.uk'},
    );
    expect(parsed.sources['Big.uk']!.length, lessThanOrEqualTo(10));
    expect(parsed.sources['Big.uk']!.first.quality, '2160p');
  });

  test('ignores malformed and non-http entries safely', () {
    const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="Test.uk",Test
udp://239.0.0.1:1234
#EXTINF:-1,No id
https://example.com/no-id.m3u8
#EXTINF:-1 tvg-id="Test.uk",Test again
https://example.com/good.m3u8
''';
    final parsed = parseM3uLineup(
      playlist,
      knownChannelIds: {'Test.uk'},
    );
    expect(parsed.sources['Test.uk']!.single.url, 'https://example.com/good.m3u8');
  });
}
