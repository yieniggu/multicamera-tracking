import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:multicamera_tracking/features/discovery/data/parsers/ssdp_parser.dart';
import 'package:multicamera_tracking/features/discovery/domain/entities/discovered_device.dart';
import 'package:multicamera_tracking/features/discovery/domain/services/network_discovery_service.dart';

class HybridNetworkDiscoveryService implements NetworkDiscoveryService {
  static const _mdnsServiceTypes = <String>[
    '_rtsp._tcp.local',
    '_onvif._tcp.local',
    '_http._tcp.local',
  ];

  static const _cameraPorts = <int>[554, 8554, 80, 443];

  final List<MDnsClient> _mdnsClients = [];
  final List<RawDatagramSocket> _ssdpSockets = [];
  final List<StreamSubscription<RawSocketEvent>> _ssdpSubscriptions = [];
  final Set<String> _probedIps = {};
  StreamController<DiscoveredDevice>? _controller;
  int _scanId = 0;

  @override
  Stream<DiscoveredDevice> discover({required bool includeDeepScan}) {
    _probedIps.clear();
    _controller = StreamController<DiscoveredDevice>.broadcast();
    final currentScanId = ++_scanId;
    unawaited(_runScan(currentScanId, includeDeepScan: includeDeepScan));
    return _controller!.stream;
  }

  @override
  Future<void> stop() async {
    _scanId++;
    final ctrl = _controller;
    _controller = null;

    for (final sub in List<StreamSubscription<RawSocketEvent>>.from(
      _ssdpSubscriptions,
    )) {
      await sub.cancel();
    }
    _ssdpSubscriptions.clear();

    for (final socket in List<RawDatagramSocket>.from(_ssdpSockets)) {
      socket.close();
    }
    _ssdpSockets.clear();

    for (final client in List<MDnsClient>.from(_mdnsClients)) {
      client.stop();
    }
    _mdnsClients.clear();

    if (ctrl != null && !ctrl.isClosed) {
      await ctrl.close();
    }
  }

  bool _isActive(int id) => _scanId == id && _controller != null;

  Future<void> _runScan(int id, {required bool includeDeepScan}) async {
    try {
      await Future.wait([
        _discoverViaMdns(id),
        _discoverViaSsdp(id),
        if (includeDeepScan) _discoverViaDeepScan(id),
      ]);
      await _emitArpEnrichment(id);
    } finally {
      final ctrl = _controller;
      if (_isActive(id) && ctrl != null && !ctrl.isClosed) {
        await ctrl.close();
        _controller = null;
      }
    }
  }

  void _emitIfActive(int id, DiscoveredDevice device) {
    final ctrl = _controller;
    if (!_isActive(id) || ctrl == null || ctrl.isClosed) return;
    ctrl.add(device);
    _scheduleProbeForIp(id, device.ipAddress);
  }

  void _scheduleProbeForIp(int id, String ip) {
    if (!_isActive(id)) return;
    if (!_probedIps.add(ip)) return;

    unawaited(() async {
      final enriched = await probeDevice(ip);
      if (enriched == null || !_isActive(id)) return;
      _emitIfActive(id, enriched);
    }());
  }

  Future<void> _discoverViaMdns(int id) async {
    final client = MDnsClient();
    _mdnsClients.add(client);
    try {
      await client.start();
      if (!_isActive(id)) return;

      for (final service in _mdnsServiceTypes) {
        if (!_isActive(id)) break;
        final ptrQuery = ResourceRecordQuery.serverPointer(service);
        await for (final ptr
            in client
                .lookup<PtrResourceRecord>(ptrQuery)
                .timeout(
                  const Duration(seconds: 2),
                  onTimeout: (sink) => sink.close(),
                )) {
          if (!_isActive(id)) break;

          final instance = ptr.domainName;
          final hostAndPort = await _resolveSrv(client, instance);
          final host = hostAndPort?.host;
          if (host == null) continue;

          final ip = await _resolveIPv4(client, host);
          if (ip == null || !_isActive(id)) continue;

          _emitIfActive(
            id,
            DiscoveredDevice(
              ipAddress: ip,
              hostName: host,
              deviceName: _friendlyInstanceName(instance),
              source: DiscoverySource.mdns,
            ),
          );
        }
      }
    } catch (_) {
      // Best-effort protocol branch.
    } finally {
      client.stop();
      _mdnsClients.remove(client);
    }
  }

  Future<({String host, int port})?> _resolveSrv(
    MDnsClient client,
    String instance,
  ) async {
    try {
      final srvQuery = ResourceRecordQuery.service(instance);
      await for (final srv
          in client
              .lookup<SrvResourceRecord>(srvQuery)
              .timeout(
                const Duration(seconds: 2),
                onTimeout: (sink) => sink.close(),
              )) {
        return (host: srv.target, port: srv.port);
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _resolveIPv4(MDnsClient client, String host) async {
    try {
      final aQuery = ResourceRecordQuery.addressIPv4(host);
      await for (final rec
          in client
              .lookup<IPAddressResourceRecord>(aQuery)
              .timeout(
                const Duration(seconds: 2),
                onTimeout: (sink) => sink.close(),
              )) {
        return rec.address.address;
      }
    } catch (_) {}
    return null;
  }

  String _friendlyInstanceName(String instance) {
    var out = instance;
    const suffix = '._tcp.local';
    if (out.endsWith(suffix)) {
      out = out.substring(0, out.length - suffix.length);
    }
    final dotIdx = out.indexOf('._');
    if (dotIdx > 0) {
      out = out.substring(0, dotIdx);
    }
    return out.trim();
  }

  Future<void> _discoverViaSsdp(int id) async {
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? sub;
    Timer? timer;
    final pendingMetadata = <Future<void>>[];
    final done = Completer<void>();

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      if (!_isActive(id)) return;

      _ssdpSockets.add(socket);
      socket.broadcastEnabled = true;
      socket.multicastHops = 2;

      final request = [
        'M-SEARCH * HTTP/1.1',
        'HOST: 239.255.255.250:1900',
        'MAN: "ssdp:discover"',
        'MX: 2',
        'ST: ssdp:all',
        '',
        '',
      ].join('\r\n');

      socket.send(
        utf8.encode(request),
        InternetAddress('239.255.255.250'),
        1900,
      );

      sub = socket.listen((event) {
        if (!_isActive(id)) return;
        if (event != RawSocketEvent.read) return;
        final dg = socket?.receive();
        if (dg == null) return;
        final response = utf8.decode(dg.data, allowMalformed: true);
        final headers = SsdpParser.parseHeaders(response);

        final location = headers['location'];
        final usn = headers['usn'];
        final server = headers['server'];
        final sourceIp = dg.address.address;

        Uri? uri;
        if (location != null) {
          uri = Uri.tryParse(location);
        }

        final locationIp = uri?.host;
        final ip = (locationIp != null && locationIp.isNotEmpty)
            ? locationIp
            : sourceIp;

        final task = () async {
          final meta = await _fetchSsdpMetadata(uri);
          if (!_isActive(id)) return;
          _emitIfActive(
            id,
            DiscoveredDevice(
              ipAddress: ip,
              hostName: locationIp,
              deviceName: meta.friendlyName ?? _deviceNameFromUsn(usn),
              vendor: meta.manufacturer ?? _vendorFromServerHeader(server),
              model: meta.modelName,
              source: DiscoverySource.ssdp,
            ),
          );
        }();
        pendingMetadata.add(task);
        unawaited(
          task.whenComplete(() {
            pendingMetadata.remove(task);
          }),
        );
      });
      _ssdpSubscriptions.add(sub);

      timer = Timer(const Duration(seconds: 3), () {
        if (!done.isCompleted) done.complete();
      });
      await done.future;
      if (pendingMetadata.isNotEmpty) {
        await Future.wait(pendingMetadata);
      }
    } catch (_) {
      // Best-effort protocol branch.
    } finally {
      timer?.cancel();
      if (sub != null) {
        await sub.cancel();
        _ssdpSubscriptions.remove(sub);
      }
      if (socket != null) {
        socket.close();
        _ssdpSockets.remove(socket);
      }
    }
  }

  Future<SsdpDeviceMetadata> _fetchSsdpMetadata(Uri? uri) async {
    if (uri == null || !uri.hasScheme) {
      return const SsdpDeviceMetadata();
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/xml,text/xml');
      final resp = await req.close().timeout(const Duration(seconds: 2));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return const SsdpDeviceMetadata();
      }
      final body = await utf8.decoder.bind(resp).join();
      return SsdpParser.parseDeviceDescription(body);
    } catch (_) {
      return const SsdpDeviceMetadata();
    } finally {
      client.close(force: true);
    }
  }

  String? _deviceNameFromUsn(String? usn) {
    if (usn == null || usn.isEmpty) return null;
    final trimmed = usn.trim();
    final idx = trimmed.indexOf('::');
    if (idx > 0) return trimmed.substring(0, idx);
    return trimmed;
  }

  String? _vendorFromServerHeader(String? server) {
    if (server == null || server.isEmpty) return null;
    final tokens = server.split(RegExp(r'[/\s]+'));
    for (final token in tokens) {
      final clean = token.trim();
      if (clean.isEmpty) continue;
      if (clean.toLowerCase().contains('upnp')) continue;
      if (RegExp(r'^\d').hasMatch(clean)) continue;
      return clean;
    }
    return null;
  }

  Future<void> _discoverViaDeepScan(int id) async {
    final subnet = await _localSubnetPrefix();
    if (subnet == null || !_isActive(id)) return;

    final ownIp = subnet.ownIp;
    final prefix = subnet.prefix;
    final tasks = <Future<void>>[];
    const maxInFlight = 32;

    for (var host = 1; host <= 254; host++) {
      if (!_isActive(id)) break;
      final ip = '$prefix.$host';
      if (ip == ownIp) continue;

      tasks.add(_probeHost(id, ip));
      if (tasks.length >= maxInFlight) {
        await Future.wait(tasks);
        tasks.clear();
      }
    }

    if (tasks.isNotEmpty && _isActive(id)) {
      await Future.wait(tasks);
    }
  }

  Future<void> _probeHost(int id, String ip) async {
    for (final port in _cameraPorts) {
      if (!_isActive(id)) return;
      Socket? socket;
      try {
        socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 220),
        );
        _emitIfActive(
          id,
          DiscoveredDevice(ipAddress: ip, source: DiscoverySource.deepScan),
        );
        return;
      } catch (_) {
        // Try next port.
      } finally {
        await socket?.close();
      }
    }
  }

  Future<({String prefix, String ownIp})?> _localSubnetPrefix() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );

      for (final nic in interfaces) {
        for (final addr in nic.addresses) {
          final ip = addr.address;
          if (!_isPrivateIPv4(ip)) continue;
          final parts = ip.split('.');
          if (parts.length != 4) continue;
          final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
          return (prefix: prefix, ownIp: ip);
        }
      }
    } catch (_) {}
    return null;
  }

  bool _isPrivateIPv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]) ?? -1;
    final b = int.tryParse(parts[1]) ?? -1;
    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    return false;
  }

  Future<void> _emitArpEnrichment(int id) async {
    if (!Platform.isAndroid) return;
    final file = File('/proc/net/arp');
    if (!await file.exists()) return;

    final lines = await file.readAsLines();
    if (lines.length <= 1) return;

    for (final line in lines.skip(1)) {
      if (!_isActive(id)) return;
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 4) continue;
      final ip = parts[0].trim();
      final mac = parts[3].trim().toLowerCase();
      if (ip.isEmpty || mac.isEmpty || mac == '00:00:00:00:00:00') continue;

      _emitIfActive(
        id,
        DiscoveredDevice(
          ipAddress: ip,
          macAddress: mac,
          source: DiscoverySource.arp,
        ),
      );
    }
  }

  @override
  Future<DiscoveredDevice?> probeDevice(
    String ipAddress, {
    String? username,
    String? password,
  }) async {
    final onvifResult = await _probeOnvif(
      ipAddress,
      username: username,
      password: password,
    );
    final banner = await _probeHttpBanner(ipAddress);

    final authProvided =
        username != null &&
        username.trim().isNotEmpty &&
        password != null &&
        password.isNotEmpty;

    final requiresAuth = onvifResult.requiresAuthentication && !authProvided;

    final modelOrBanner = [
      onvifResult.model,
      onvifResult.friendlyName,
      banner,
    ].whereType<String>().join(' ');

    final type = _classifyDeviceType(
      modelOrBanner: modelOrBanner,
      onvifSupported: onvifResult.supported,
    );
    final confidence = _inferConfidence(
      type: type,
      onvifSupported: onvifResult.supported,
      requiresAuthentication: requiresAuth,
    );

    if (!onvifResult.supported && type == DiscoveredDeviceType.networkDevice) {
      final result = DiscoveredDevice(
        ipAddress: ipAddress,
        source: DiscoverySource.probe,
        deviceType: type,
        confidence: confidence,
      );
      debugPrint(
        '[DISCOVERY-PROBE] ip=$ipAddress type=${result.deviceType.name} conf=${result.confidence.name} onvif=${result.onvifSupported} authReq=${result.requiresAuthentication}',
      );
      return result;
    }

    if (!onvifResult.supported && type == DiscoveredDeviceType.unknown) {
      return null;
    }

    final result = DiscoveredDevice(
      ipAddress: ipAddress,
      source: DiscoverySource.probe,
      deviceName: onvifResult.friendlyName,
      vendor: onvifResult.vendor,
      model: onvifResult.model,
      deviceType: type,
      confidence: confidence,
      onvifSupported: onvifResult.supported,
      rtspSupported: false,
      requiresAuthentication: requiresAuth,
      authenticationVerified: authProvided && onvifResult.authenticated,
    );
    debugPrint(
      '[DISCOVERY-PROBE] ip=$ipAddress type=${result.deviceType.name} conf=${result.confidence.name} onvif=${result.onvifSupported} authReq=${result.requiresAuthentication} authOk=${result.authenticationVerified}',
    );
    return result;
  }

  @override
  Future<String?> fetchOnvifStreamUri(
    String ipAddress, {
    String? username,
    String? password,
  }) async {
    const getServicesBody = '''
<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">
  <s:Body>
    <tds:GetServices xmlns:tds="http://www.onvif.org/ver10/device/wsdl">
      <tds:IncludeCapability>false</tds:IncludeCapability>
    </tds:GetServices>
  </s:Body>
</s:Envelope>
''';
    final deviceUri = Uri.parse('http://$ipAddress/onvif/device_service');
    final servicesResp = await _soapPost(
      deviceUri,
      getServicesBody,
      username: username,
      password: password,
    );
    if (servicesResp == null ||
        servicesResp.statusCode < 200 ||
        servicesResp.statusCode >= 300) {
      return null;
    }

    final servicesXml = servicesResp.body;
    final mediaXAddr =
        _onvifServiceXAddr(
          servicesXml,
          'http://www.onvif.org/ver10/media/wsdl',
        ) ??
        _onvifServiceXAddr(
          servicesXml,
          'http://www.onvif.org/ver20/media/wsdl',
        );
    if (mediaXAddr == null || mediaXAddr.isEmpty) return null;

    final mediaUri = _normalizeServiceUri(mediaXAddr, ipAddress);
    if (mediaUri == null) return null;

    final profileToken = await _fetchOnvifProfileToken(
      mediaUri,
      username: username,
      password: password,
    );
    if (profileToken == null || profileToken.isEmpty) return null;

    final streamUri = await _fetchOnvifStreamUri(
      mediaUri,
      profileToken: profileToken,
      username: username,
      password: password,
    );
    if (streamUri == null || streamUri.isEmpty) return null;

    return _injectCredentialsIntoUri(
      streamUri,
      username: username,
      password: password,
    );
  }

  String? _onvifServiceXAddr(String xml, String namespace) {
    final escapedNs = RegExp.escape(namespace);
    final expr = RegExp(
      '<(?:\\w+:)?Service>.*?<(?:\\w+:)?Namespace>\\s*$escapedNs\\s*</(?:\\w+:)?Namespace>.*?<(?:\\w+:)?XAddr>\\s*(.*?)\\s*</(?:\\w+:)?XAddr>',
      caseSensitive: false,
      dotAll: true,
    );
    final match = expr.firstMatch(xml);
    return match?.group(1)?.trim();
  }

  Uri? _normalizeServiceUri(String xAddr, String ipAddress) {
    final parsed = Uri.tryParse(xAddr.trim());
    if (parsed == null) return null;
    if (parsed.hasScheme) return parsed;

    final normalizedPath = xAddr.startsWith('/') ? xAddr : '/$xAddr';
    return Uri.parse('http://$ipAddress$normalizedPath');
  }

  Future<String?> _fetchOnvifProfileToken(
    Uri mediaUri, {
    String? username,
    String? password,
  }) async {
    const getProfilesV10 = '''
<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">
  <s:Body>
    <trt:GetProfiles xmlns:trt="http://www.onvif.org/ver10/media/wsdl"/>
  </s:Body>
</s:Envelope>
''';
    const getProfilesV20 = '''
<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">
  <s:Body>
    <tr2:GetProfiles xmlns:tr2="http://www.onvif.org/ver20/media/wsdl"/>
  </s:Body>
</s:Envelope>
''';

    final v10Resp = await _soapPost(
      mediaUri,
      getProfilesV10,
      username: username,
      password: password,
    );
    final v10Token = _parseOnvifProfileToken(v10Resp?.body);
    if (v10Token != null) return v10Token;

    final v20Resp = await _soapPost(
      mediaUri,
      getProfilesV20,
      username: username,
      password: password,
    );
    return _parseOnvifProfileToken(v20Resp?.body);
  }

  String? _parseOnvifProfileToken(String? xml) {
    if (xml == null || xml.isEmpty) return null;

    final attrMatch = RegExp(
      '<(?:\\w+:)?Profiles\\b[^>]*\\btoken="([^"]+)"',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(xml);
    final attrToken = attrMatch?.group(1)?.trim();
    if (attrToken != null && attrToken.isNotEmpty) return attrToken;

    final tagMatch = RegExp(
      '<(?:\\w+:)?ProfileToken>\\s*(.*?)\\s*</(?:\\w+:)?ProfileToken>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(xml);
    final tagToken = tagMatch?.group(1)?.trim();
    if (tagToken != null && tagToken.isNotEmpty) return tagToken;

    return null;
  }

  Future<String?> _fetchOnvifStreamUri(
    Uri mediaUri, {
    required String profileToken,
    String? username,
    String? password,
  }) async {
    final bodyV10 =
        '''
<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">
  <s:Body>
    <trt:GetStreamUri xmlns:trt="http://www.onvif.org/ver10/media/wsdl" xmlns:tt="http://www.onvif.org/ver10/schema">
      <trt:StreamSetup>
        <tt:Stream>RTP-Unicast</tt:Stream>
        <tt:Transport>
          <tt:Protocol>RTSP</tt:Protocol>
        </tt:Transport>
      </trt:StreamSetup>
      <trt:ProfileToken>$profileToken</trt:ProfileToken>
    </trt:GetStreamUri>
  </s:Body>
</s:Envelope>
''';
    final bodyV20 =
        '''
<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">
  <s:Body>
    <tr2:GetStreamUri xmlns:tr2="http://www.onvif.org/ver20/media/wsdl">
      <tr2:Protocol>RTSP</tr2:Protocol>
      <tr2:ProfileToken>$profileToken</tr2:ProfileToken>
    </tr2:GetStreamUri>
  </s:Body>
</s:Envelope>
''';

    final v10Resp = await _soapPost(
      mediaUri,
      bodyV10,
      username: username,
      password: password,
    );
    final v10Uri = _xmlTagValue(v10Resp?.body, 'Uri');
    if (v10Uri != null && v10Uri.isNotEmpty) return v10Uri;

    final v20Resp = await _soapPost(
      mediaUri,
      bodyV20,
      username: username,
      password: password,
    );
    final v20Uri = _xmlTagValue(v20Resp?.body, 'Uri');
    if (v20Uri != null && v20Uri.isNotEmpty) return v20Uri;

    return null;
  }

  String _injectCredentialsIntoUri(
    String uri, {
    String? username,
    String? password,
  }) {
    final user = username?.trim() ?? '';
    final pass = password ?? '';
    if (user.isEmpty) return uri;

    final parsed = Uri.tryParse(uri);
    if (parsed == null || parsed.host.isEmpty || parsed.userInfo.isNotEmpty) {
      return uri;
    }

    return parsed
        .replace(
          userInfo: '${Uri.encodeComponent(user)}:${Uri.encodeComponent(pass)}',
        )
        .toString();
  }

  Future<
    ({
      bool supported,
      bool requiresAuthentication,
      bool authenticated,
      String? vendor,
      String? model,
      String? friendlyName,
    })
  >
  _probeOnvif(String ipAddress, {String? username, String? password}) async {
    const getServicesBody = '''
<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">
  <s:Body>
    <tds:GetServices xmlns:tds="http://www.onvif.org/ver10/device/wsdl">
      <tds:IncludeCapability>false</tds:IncludeCapability>
    </tds:GetServices>
  </s:Body>
</s:Envelope>
''';
    const getDeviceInfoBody = '''
<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">
  <s:Body>
    <tds:GetDeviceInformation xmlns:tds="http://www.onvif.org/ver10/device/wsdl"/>
  </s:Body>
</s:Envelope>
''';
    final uri = Uri.parse('http://$ipAddress/onvif/device_service');

    final servicesResp = await _soapPost(
      uri,
      getServicesBody,
      username: username,
      password: password,
    );
    if (servicesResp == null) {
      return (
        supported: false,
        requiresAuthentication: false,
        authenticated: false,
        vendor: null,
        model: null,
        friendlyName: null,
      );
    }

    final code = servicesResp.statusCode;
    final authRequired = code == 401 || code == 403;
    final supportsOnvif = code >= 200 && code < 300;
    if (!supportsOnvif) {
      return (
        supported: false,
        requiresAuthentication: authRequired,
        authenticated: false,
        vendor: null,
        model: null,
        friendlyName: null,
      );
    }

    final infoResp = await _soapPost(
      uri,
      getDeviceInfoBody,
      username: username,
      password: password,
    );
    final infoCode = infoResp?.statusCode ?? 0;
    final infoBody = infoResp?.body;
    final model = _xmlTagValue(infoBody, 'Model');
    final vendor = _xmlTagValue(infoBody, 'Manufacturer');
    final name =
        _xmlTagValue(infoBody, 'SerialNumber') ??
        _xmlTagValue(infoBody, 'HardwareId');

    return (
      supported: true,
      requiresAuthentication:
          authRequired || infoCode == 401 || infoCode == 403,
      authenticated: username != null && username.isNotEmpty && infoCode == 200,
      vendor: vendor,
      model: model,
      friendlyName: name,
    );
  }

  String? _xmlTagValue(String? xml, String tag) {
    if (xml == null || xml.isEmpty) return null;
    final expr = RegExp(
      '<(?:\\w+:)?$tag>(.*?)</(?:\\w+:)?$tag>',
      caseSensitive: false,
      dotAll: true,
    );
    final match = expr.firstMatch(xml);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<({int statusCode, String body})?> _soapPost(
    Uri uri,
    String body, {
    String? username,
    String? password,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final hasAuth =
        username != null &&
        username.trim().isNotEmpty &&
        password != null &&
        password.isNotEmpty;
    final authUser = username ?? '';
    final authPass = password ?? '';
    if (hasAuth) {
      client.authenticate = (uri, scheme, realm) async {
        final safeRealm = realm ?? '';
        if (scheme.toLowerCase() == 'digest') {
          client.addCredentials(
            uri,
            safeRealm,
            HttpClientDigestCredentials(authUser, authPass),
          );
        } else {
          client.addCredentials(
            uri,
            safeRealm,
            HttpClientBasicCredentials(authUser, authPass),
          );
        }
        return true;
      };
    }

    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType(
        'application',
        'soap+xml',
        charset: 'utf-8',
      );
      req.write(body);
      final resp = await req.close().timeout(const Duration(seconds: 3));
      final respBody = await utf8.decoder.bind(resp).join();
      return (statusCode: resp.statusCode, body: respBody);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<String?> _probeHttpBanner(String ipAddress) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final req = await client.getUrl(Uri.parse('http://$ipAddress/'));
      final resp = await req.close().timeout(const Duration(seconds: 2));
      if (resp.statusCode < 200 || resp.statusCode >= 400) return null;
      final body = await utf8.decoder.bind(resp).join();
      if (body.isEmpty) return null;
      final end = body.length > 4096 ? 4096 : body.length;
      return body.substring(0, end);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  DiscoveredDeviceType _classifyDeviceType({
    required String modelOrBanner,
    required bool onvifSupported,
  }) {
    final lower = modelOrBanner.toLowerCase();
    const recorderKeywords = ['nvr', 'dvr', 'xvr', 'recorder', 'xmeye'];
    const cameraKeywords = [
      'camera',
      'cam',
      'ipc',
      'ipcam',
      'hfw',
      'bullet',
      'dome',
    ];
    const infraKeywords = [
      'router',
      'gateway',
      'tp-link',
      'mikrotik',
      'ubiquiti',
    ];

    if (recorderKeywords.any(lower.contains)) {
      return DiscoveredDeviceType.recorder;
    }
    if (cameraKeywords.any(lower.contains)) {
      return DiscoveredDeviceType.camera;
    }
    if (infraKeywords.any(lower.contains)) {
      return DiscoveredDeviceType.networkDevice;
    }
    if (onvifSupported) {
      return DiscoveredDeviceType.cameraOrRecorder;
    }
    return DiscoveredDeviceType.unknown;
  }

  DiscoveryConfidence _inferConfidence({
    required DiscoveredDeviceType type,
    required bool onvifSupported,
    required bool requiresAuthentication,
  }) {
    if (type == DiscoveredDeviceType.networkDevice) {
      return DiscoveryConfidence.medium;
    }
    if (type == DiscoveredDeviceType.camera ||
        type == DiscoveredDeviceType.recorder) {
      return requiresAuthentication
          ? DiscoveryConfidence.medium
          : DiscoveryConfidence.high;
    }
    if (onvifSupported) {
      return DiscoveryConfidence.medium;
    }
    return DiscoveryConfidence.low;
  }
}
