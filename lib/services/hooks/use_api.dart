import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api_service.dart';

enum ApiStatus { initial, loading, success, error }

class ApiState<T> {
  final ApiStatus status;
  final T? data;
  final String? error;
  final int? statusCode;

  const ApiState({
    this.status = ApiStatus.initial,
    this.data,
    this.error,
    this.statusCode,
  });

  ApiState<T> copyWith({
    ApiStatus? status,
    T? data,
    String? error,
    int? statusCode,
  }) {
    return ApiState(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error ?? this.error,
      statusCode: statusCode ?? this.statusCode,
    );
  }

  bool get isLoading => status == ApiStatus.loading;
  bool get isSuccess => status == ApiStatus.success;
  bool get isError => status == ApiStatus.error;
  bool get isInitial => status == ApiStatus.initial;
}

class UseApi<T> extends ChangeNotifier {
  final ApiService _apiService;
  final T Function(dynamic)? parser;
  
  ApiState<T> _state = const ApiState();
  Timer? _debounceTimer;

  UseApi({
    ApiService? injected,
    this.parser,
  }) : _apiService = injected ?? apiService;

  ApiState<T> get state => _state;
  T? get data => _state.data;
  bool get isLoading => _state.isLoading;
  bool get isError => _state.isError;
  String? get error => _state.error;

  Future<void> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    _setLoading();
    
    try {
      final response = await _apiService.get<T>(
        endpoint,
        parser: parser,
        queryParams: queryParams,
      );
      
      if (response.success) {
        _setSuccess(response.data);
      } else {
        _setError(response.message ?? 'Unknown error');
      }
    } on ApiException catch (e) {
      _setError(e.message, statusCode: e.statusCode);
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> post(
    String endpoint, {
    required Map<String, dynamic> body,
  }) async {
    _setLoading();
    
    try {
      final response = await _apiService.post<T>(
        endpoint,
        body: body,
        parser: parser,
      );
      
      if (response.success) {
        _setSuccess(response.data);
      } else {
        _setError(response.message ?? 'Unknown error');
      }
    } on ApiException catch (e) {
      _setError(e.message, statusCode: e.statusCode);
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> put(
    String endpoint, {
    required Map<String, dynamic> body,
  }) async {
    _setLoading();
    
    try {
      final response = await _apiService.put<T>(
        endpoint,
        body: body,
        parser: parser,
      );
      
      if (response.success) {
        _setSuccess(response.data);
      } else {
        _setError(response.message ?? 'Unknown error');
      }
    } on ApiException catch (e) {
      _setError(e.message, statusCode: e.statusCode);
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> delete(String endpoint) async {
    _setLoading();
    
    try {
      final response = await _apiService.delete<T>(
        endpoint,
        parser: parser,
      );
      
      if (response.success) {
        _setSuccess(response.data);
      } else {
        _setError(response.message ?? 'Unknown error');
      }
    } on ApiException catch (e) {
      _setError(e.message, statusCode: e.statusCode);
    } catch (e) {
      _setError(e.toString());
    }
  }

  void search(
    String endpoint, {
    required String query,
    Map<String, String>? additionalParams,
    Duration debounce = const Duration(milliseconds: 500),
  }) {
    _debounceTimer?.cancel();
    
    _debounceTimer = Timer(debounce, () {
      final params = <String, String>{'search': query};
      if (additionalParams != null) {
        params.addAll(additionalParams);
      }
      get(endpoint, queryParams: params);
    });
  }

  void _setLoading() {
    _state = _state.copyWith(status: ApiStatus.loading, error: null);
    notifyListeners();
  }

  void _setSuccess(T? data) {
    _state = _state.copyWith(
      status: ApiStatus.success,
      data: data,
      error: null,
    );
    notifyListeners();
  }

  void _setError(String error, {int? statusCode}) {
    _state = _state.copyWith(
      status: ApiStatus.error,
      error: error,
      statusCode: statusCode,
    );
    notifyListeners();
  }

  void reset() {
    _state = const ApiState();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

// Specialized hooks for POS operations
class UseBaraa extends UseApi<Map<String, dynamic>> {
  UseBaraa() : super(
    injected: posApiService,
    parser: (data) => data as Map<String, dynamic>,
  );

  Future<void> getBaraaJagsaalt({String? search, String? category}) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (category != null && category.isNotEmpty) params['category'] = category;
    
    await get('/baraa/jagsaalt', queryParams: params.isNotEmpty ? params : null);
  }

  Future<void> getBaraa(String id) async {
    await get('/baraa/$id');
  }

  Future<void> createBaraa(Map<String, dynamic> baraa) async {
    await post('/baraa', body: baraa);
  }

  Future<void> updateBaraa(String id, Map<String, dynamic> baraa) async {
    await put('/baraa/$id', body: baraa);
  }

  Future<void> deleteBaraa(String id) async {
    await delete('/baraa/$id');
  }
}

class UseKhariltsagch extends UseApi<Map<String, dynamic>> {
  UseKhariltsagch() : super(
    injected: apiService,
    parser: (data) => data as Map<String, dynamic>,
  );

  Future<void> getKhariltsagchJagsaalt({String? search}) async {
    final params = search != null && search.isNotEmpty 
        ? {'search': search} 
        : null;
    await get('/khariltsagch/jagsaalt', queryParams: params);
  }

  Future<void> getKhariltsagch(String id) async {
    await get('/khariltsagch/$id');
  }

  Future<void> createKhariltsagch(Map<String, dynamic> khariltsagch) async {
    await post('/khariltsagch', body: khariltsagch);
  }

  Future<void> updateKhariltsagch(String id, Map<String, dynamic> khariltsagch) async {
    await put('/khariltsagch/$id', body: khariltsagch);
  }
}

class UseBorluulalt extends UseApi<Map<String, dynamic>> {
  UseBorluulalt() : super(
    injected: posApiService,
    parser: (data) => data as Map<String, dynamic>,
  );

  Future<void> getBorluulaltJagsaalt({
    DateTime? startDate,
    DateTime? endDate,
    String? cashierId,
  }) async {
    final params = <String, String>{};
    if (startDate != null) params['startDate'] = startDate.toIso8601String();
    if (endDate != null) params['endDate'] = endDate.toIso8601String();
    if (cashierId != null) params['cashierId'] = cashierId;
    
    await get('/borluulalt/jagsaalt', queryParams: params.isNotEmpty ? params : null);
  }

  Future<void> createBorluulalt(Map<String, dynamic> borluulalt) async {
    await post('/borluulalt', body: borluulalt);
  }

  Future<void> getBorluulalt(String id) async {
    await get('/borluulalt/$id');
  }
}

class UseTailan extends UseApi<Map<String, dynamic>> {
  UseTailan() : super(
    injected: apiService,
    parser: (data) => data as Map<String, dynamic>,
  );

  Future<void> getSalesTailan({
    DateTime? startDate,
    DateTime? endDate,
    String? type = 'daily',
  }) async {
    final params = <String, String>{'type': type ?? 'daily'};
    if (startDate != null) params['startDate'] = startDate.toIso8601String();
    if (endDate != null) params['endDate'] = endDate.toIso8601String();
    
    await get('/tailan/borluulalt', queryParams: params);
  }

  Future<void> getBestSellers({DateTime? startDate, DateTime? endDate}) async {
    final params = <String, String>{};
    if (startDate != null) params['startDate'] = startDate.toIso8601String();
    if (endDate != null) params['endDate'] = endDate.toIso8601String();
    
    await get('/tailan/bestSellers', queryParams: params.isNotEmpty ? params : null);
  }
}
