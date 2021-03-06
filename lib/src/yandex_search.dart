part of yandex_mapkit;

class YandexSearch {
  static const String _channelName = 'yandex_mapkit/yandex_search';

  static const MethodChannel _channel = MethodChannel(_channelName);

  static int _nextCallbackId = 0;
  static final Map<int, SuggestSessionCallback> _suggestSessionsById = {};

  static Future<CancelSuggestCallback> getSuggestions({
    required String address,
    required Point southWestPoint,
    required Point northEastPoint,
    required SuggestType suggestType,
    required bool suggestWords,
    required SuggestSessionCallback onSuggest
  }) async {
    _channel.setMethodCallHandler(_handleMethodCall);

    final listenerId = _nextCallbackId++;
    _suggestSessionsById[listenerId] = onSuggest;

    await _channel.invokeMethod<void>(
      'getSuggestions',
      <String, dynamic>{
        'formattedAddress': address,
        'southWestLatitude': southWestPoint.latitude,
        'southWestLongitude': southWestPoint.longitude,
        'northEastLatitude': northEastPoint.latitude,
        'northEastLongitude': northEastPoint.longitude,
        'suggestType': suggestType.index,
        'suggestWords': suggestWords,
        'listenerId': listenerId
      }
    );

    return () => _cancelSuggestSession(listenerId);
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSuggestListenerResponse':
        _onSuggestListenerResponse(call.arguments);
        break;
      case 'onSuggestListenerError':
        _onSuggestListenerError(call.arguments);
        break;
      case 'onSuggestListenerRemove':
        _onSuggestListenerRemove(call.arguments);
        break;
      default:
        throw MissingPluginException();
    }
  }

  static void _onSuggestListenerRemove(dynamic arguments) {
    _cancelSuggestSession(arguments['listenerId']);
  }

  static Future<void> _cancelSuggestSession(int listenerId) async {
    if (_suggestSessionsById.containsKey(listenerId)) {
      _suggestSessionsById.remove(listenerId);
      await _channel.invokeMethod<void>(
        'cancelSuggestSession',
        <String, dynamic>{
          'listenerId': listenerId
        }
      );
    }
  }

  static void _onSuggestListenerResponse(dynamic arguments) {
    final List<dynamic> suggests = arguments['response'];
    final suggestItems = suggests.map((dynamic sug) {
      return SuggestItem(
        title: sug['title'],
        subtitle: sug['subtitle'],
        displayText: sug['displayText'],
        searchText: sug['searchText'],
        type: SuggestItemType.values[sug['type']],
        tags: sug['tags'],
      );
    }).toList();
    final int listenerId = arguments['listenerId'];

    _suggestSessionsById[listenerId]!(suggestItems);
    _cancelSuggestSession(listenerId);
  }

  static void _onSuggestListenerError(dynamic arguments) {
    _cancelSuggestSession(arguments['listenerId']);
  }
}
