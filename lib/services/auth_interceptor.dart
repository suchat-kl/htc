import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class AuthInterceptor extends Interceptor {
  final ApiService apiService;

  bool _isRefreshing = false;
  final List<Map<String, dynamic>> _pendingRequests = [];

  AuthInterceptor(this.apiService);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final path = options.path;
    final method = options.method;

    // Public endpoints - no auth needed
    final publicGetEndpoints = ['/api/auth/ticker-msg'];
    final publicEndpoints = [
      '/api/auth/login',
      // '/api/auth/register',
      '/api/auth/refresh',
      '/api/auth/refresh-token',
      '/api/auth/hello',
      '/api/auth/foodtypes',
      '/api/auth/tfoods',
      '/api/auth/bookings',
      '/api/auth/searchBookings',
      '/api/auth/documentstatus',
      // '/api/auth/bookingID',
      // '/api/auth/',
    ];

    final isPublicGet =
        publicGetEndpoints.any((e) => path.contains(e)) && method == 'GET';
    final isPublicAll = publicEndpoints.any((e) => path.contains(e));
    final needsAuth = !isPublicGet && !isPublicAll;

    if (needsAuth) {
      final token = await apiService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Only handle 401/403 for authenticated endpoints
    if (err.response?.statusCode == 401 || err.response?.statusCode == 403) {
      final requestPath = err.requestOptions.path;

      // Don't refresh for auth endpoints
      if (requestPath.contains('/auth/login') ||
          requestPath.contains('/auth/refresh') ||
          requestPath.contains('/auth/refresh-token') ||
          requestPath.contains('/auth/logout')) {
        return handler.next(err);
      }

      // ✅ CRITICAL: If already refreshing, queue the request
      if (_isRefreshing) {
        debugPrint('⏳ Refresh already in progress, queuing: $requestPath');
        _pendingRequests.add({
          'options': err.requestOptions,
          'handler': handler,
        });
        return;
      }

      // Start refreshing
      _isRefreshing = true;
      debugPrint('🔄 Starting token refresh...');

      try {
        await apiService.refreshToken();
        _isRefreshing = false;

        // Get new token
        final newToken = await apiService.getAccessToken();

        // ✅ Retry ALL pending requests
        debugPrint(
          '✅ Token refreshed, retrying ${_pendingRequests.length + 1} requests',
        );

        // Retry pending requests first
        for (final pending in _pendingRequests) {
          final opts = pending['options'] as RequestOptions;
          final hdlr = pending['handler'] as ErrorInterceptorHandler;
          opts.headers['Authorization'] = 'Bearer $newToken';
          _retryRequest(opts, hdlr);
        }
        _pendingRequests.clear();

        // Retry the current request
        err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
        _retryRequest(err.requestOptions, handler);
      } catch (e) {
        debugPrint('❌ Token refresh failed: $e');
        _isRefreshing = false;

        // Reject all pending requests
        for (final pending in _pendingRequests) {
          final hdlr = pending['handler'] as ErrorInterceptorHandler;
          hdlr.reject(err);
        }
        _pendingRequests.clear();

        // Reject current request
        handler.reject(err);

        // Force logout on refresh failure
        await apiService.logout();
      }
    } else {
      handler.next(err);
    }
  }

  void _retryRequest(RequestOptions options, ErrorInterceptorHandler handler) {
    debugPrint('🔄 Retrying: ${options.path}');
    apiService.dio
        .fetch(options)
        .then(
          (response) {
            debugPrint('✅ Retry success: ${options.path}');
            handler.resolve(response);
          },
          onError: (e) {
            debugPrint('❌ Retry failed: ${options.path}');
            if (e is DioException) {
              handler.reject(e);
            } else {
              handler.reject(DioException(requestOptions: options, error: e));
            }
          },
        );
  }
}
