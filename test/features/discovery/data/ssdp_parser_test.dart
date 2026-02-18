import 'package:flutter_test/flutter_test.dart';
import 'package:multicamera_tracking/features/discovery/data/parsers/ssdp_parser.dart';

void main() {
  group('SsdpParser.parseHeaders', () {
    test('parses SSDP response headers case-insensitively', () {
      const response = '''
HTTP/1.1 200 OK
CACHE-CONTROL: max-age=1800
DATE: Tue, 17 Feb 2026 10:00:00 GMT
EXT:
LOCATION: http://192.168.1.25:80/description.xml
SERVER: Linux/4.9 UPnP/1.0 CameraOS/1.0
ST: urn:schemas-upnp-org:device:Basic:1
USN: uuid:camera-001::urn:schemas-upnp-org:device:Basic:1

''';

      final headers = SsdpParser.parseHeaders(response);

      expect(headers['location'], 'http://192.168.1.25:80/description.xml');
      expect(headers['server'], 'Linux/4.9 UPnP/1.0 CameraOS/1.0');
      expect(
        headers['usn'],
        'uuid:camera-001::urn:schemas-upnp-org:device:Basic:1',
      );
    });
  });

  group('SsdpParser.parseDeviceDescription', () {
    test('extracts friendly name, manufacturer and model from xml', () {
      const xml = '''
<?xml version="1.0"?>
<root>
  <device>
    <friendlyName>Front Door Camera</friendlyName>
    <manufacturer>AcmeVision</manufacturer>
    <modelName>AV-2000</modelName>
  </device>
</root>
''';

      final meta = SsdpParser.parseDeviceDescription(xml);

      expect(meta.friendlyName, 'Front Door Camera');
      expect(meta.manufacturer, 'AcmeVision');
      expect(meta.modelName, 'AV-2000');
    });

    test('returns empty metadata when tags are missing', () {
      const xml = '<root><device></device></root>';

      final meta = SsdpParser.parseDeviceDescription(xml);

      expect(meta.friendlyName, isNull);
      expect(meta.manufacturer, isNull);
      expect(meta.modelName, isNull);
    });
  });
}
