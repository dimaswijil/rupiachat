import 'package:flutter/material.dart';
import '../../../services/call_api_service.dart';

class CallHistoryController extends ChangeNotifier {
  final CallApiService _apiService = CallApiService();

  List<Map<String, dynamic>> _calls = [];
  bool _loading = true;
  String _searchQuery = '';

  // Getters
  List<Map<String, dynamic>> get calls => _calls;
  bool get loading => _loading;
  String get searchQuery => _searchQuery;

  List<Map<String, dynamic>> get filteredCalls {
    if (_searchQuery.isEmpty) return _calls;
    final query = _searchQuery.toLowerCase();
    return _calls.where((c) {
      final name = (c['other_user_name'] ?? '').toString().toLowerCase();
      final groupName = (c['group_name'] ?? '').toString().toLowerCase();
      return name.contains(query) || groupName.contains(query);
    }).toList();
  }

  /// Memuat riwayat panggilan dari server API
  Future<void> loadCallLogs() async {
    _loading = true;
    notifyListeners();

    try {
      final fetchedCalls = await _apiService.fetchCallLogs();
      _calls = fetchedCalls;
    } catch (e) {
      debugPrint('CallHistoryController loadCallLogs Error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Memperbarui kueri pencarian riwayat panggilan
  void updateSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      notifyListeners();
    }
  }
}
