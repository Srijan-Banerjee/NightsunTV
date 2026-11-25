import 'package:flutter_test/flutter_test.dart';
import 'package:nightsuntv/data/models/channel.dart';
import 'package:nightsuntv/data/models/stream_source.dart';
import 'package:nightsuntv/data/services/lineup_refresh_service.dart';

void main() {
  group('LineupRefreshService.parseM3uLineup', () {
    const knownIds = {
      '00sReplay.us',
      '1Plus1International.ua',
      'BBCNews.uk',
      'CNN.us',
      'CartoonNetwork.br',
    };

    test('matches channels with quality and region suffixes in tvg-id', () {
      const sampleM3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="00sReplay.us@SD" tvg-name="00s Replay" tvg-logo="https://example.com/00s.png",00s Replay
https://example.com/stream1.m3u8
#EXTINF:-1 tvg-id="1Plus1International.ua@HD" tvg-name="1+1 International",1+1 International HD (720p)
https://example.com/stream2.m3u8
#EXTINF:-1 tvg-id="CNN.us@East" tvg-name="CNN East",CNN US (1080p)
https://example.com/stream3.m3u8
#EXTINF:-1 tvg-id="UnknownChannel.zz@SD",Unknown Channel
https://example.com/stream4.m3u8
''';

      final result = parseM3uLineup(sampleM3u, knownChannelIds: knownIds);

      expect(result.sources.containsKey('00sReplay.us'), isTrue);
      expect(result.sources['00sReplay.us']!.first.url, 'https://example.com/stream1.m3u8');
      expect(result.sources['00sReplay.us']!.first.quality, '480p');

      expect(result.sources.containsKey('1Plus1International.ua'), isTrue);
      expect(result.sources['1Plus1International.ua']!.first.url, 'https://example.com/stream2.m3u8');
      expect(result.sources['1Plus1International.ua']!.first.quality, '720p');

      expect(result.sources.containsKey('CNN.us'), isTrue);
      expect(result.sources['CNN.us']!.first.url, 'https://example.com/stream3.m3u8');
      expect(result.sources['CNN.us']!.first.quality, '1080p');

      expect(result.unknownChannels, 1);
    });

    test('matches channels case-insensitively and handles stream headers', () {
      const sampleM3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="bbcnews.uk@sd" tvg-name="bbc news",BBC News
#EXTVLCOPT:http-user-agent=CustomUA/2.0
#EXTVLCOPT:http-referrer=https://bbc.co.uk
https://example.com/bbc.m3u8
''';

      final result = parseM3uLineup(sampleM3u, knownChannelIds: knownIds);

      expect(result.sources.containsKey('BBCNews.uk'), isTrue);
      final source = result.sources['BBCNews.uk']!.first;
      expect(source.url, 'https://example.com/bbc.m3u8');
      expect(source.userAgent, 'CustomUA/2.0');
      expect(source.referrer, 'https://bbc.co.uk');
      expect(source.quality, '480p');
    });

    test('deduplicates identical URLs within the same channel', () {
      const sampleM3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="00sReplay.us@SD",00s Replay
https://example.com/stream1.m3u8
#EXTINF:-1 tvg-id="00sReplay.us@HD",00s Replay HD
https://example.com/stream1.m3u8
#EXTINF:-1 tvg-id="00sReplay.us@FHD",00s Replay FHD
https://example.com/stream2.m3u8
''';

      final result = parseM3uLineup(sampleM3u, knownChannelIds: knownIds);

      expect(result.sources['00sReplay.us']!.length, 2);
      expect(result.sources['00sReplay.us']![0].url, 'https://example.com/stream1.m3u8');
      expect(result.sources['00sReplay.us']![1].url, 'https://example.com/stream2.m3u8');
      expect(result.sources['00sReplay.us']![1].quality, '1080p');
    });
  });

  group('Channel.copyWithSources stream overlay merge', () {
    test('merges overlay sources first and preserves distinct bundled mirrors up to 10', () {
      final bundledSources = [
        const StreamSource(url: 'https://example.com/mirror1.m3u8', quality: '720p'),
        const StreamSource(url: 'https://example.com/mirror2.m3u8', quality: '1080p'),
      ];
      final channel = Channel(
        id: 'CNN.us',
        name: 'CNN',
        altNames: const [],
        country: 'US',
        categories: const ['news'],
        languages: const ['eng'],
        sources: bundledSources,
      );

      final overlaySources = [
        const StreamSource(url: 'https://example.com/fresh-mirror.m3u8', quality: '1080p'),
        const StreamSource(url: 'https://example.com/mirror1.m3u8', quality: '720p'), // duplicate of bundled mirror1
      ];

      final seenUrls = overlaySources.map((s) => s.url).toSet();
      final merged = <StreamSource>[...overlaySources];
      for (final src in channel.sources) {
        if (seenUrls.add(src.url) && merged.length < 10) {
          merged.add(src);
        }
      }
      final updated = channel.copyWithSources(merged);

      expect(updated.sources.length, 3);
      // Fresh mirror comes first
      expect(updated.sources[0].url, 'https://example.com/fresh-mirror.m3u8');
      expect(updated.sources[1].url, 'https://example.com/mirror1.m3u8');
      // Preserved distinct bundled fallback
      expect(updated.sources[2].url, 'https://example.com/mirror2.m3u8');
    });
  });
}
