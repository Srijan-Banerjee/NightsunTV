import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightsuntv/data/repositories/catalog_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled catalog is complete, indexed and playable',
    () async {
      final data = await rootBundle.load('assets/data/catalog.json');
      final bytes = data.buffer
          .asUint8List(data.offsetInBytes, data.lengthInBytes);
      final catalog = parseCatalogBytes(bytes);

      expect(catalog.channels.length, greaterThan(10000));
      expect(catalog.sourceCount, greaterThan(16000));
      expect(catalog.countries.length, greaterThan(150));
      expect(catalog.languages.length, greaterThan(150));
      expect(catalog.categories.length, greaterThan(20));
      expect(catalog.nsfwCount, greaterThanOrEqualTo(2));
      expect(catalog.byId.length, catalog.channels.length);
      expect(catalog.generatedAt, isNotNull);

      var channelsWithLogos = 0;
      var multiSource = 0;
      for (final channel in catalog.channels) {
        expect(channel.sources, isNotEmpty, reason: channel.id);
        if (channel.hasLogo) channelsWithLogos++;
        if (channel.sources.length > 1) multiSource++;
        final uri = Uri.tryParse(channel.sources.first.url);
        expect(uri, isNotNull, reason: channel.id);
        expect(
          uri!.scheme == 'http' || uri.scheme == 'https',
          isTrue,
          reason: '${channel.id} has a non-HTTP source',
        );
      }
      expect(channelsWithLogos, greaterThan(9000));
      expect(multiSource, greaterThan(2000));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
