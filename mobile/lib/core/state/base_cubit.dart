import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/network/api_response.dart';
import 'package:syntrace/core/state/base_state.dart';

/// ═══════════════════════════════════════════════════════════
/// Base Cubit
///
/// Base class for application cubits.
/// Provides:
/// - handleApiCall(): handles loading, success, and error states.
/// - emitLoading(), emitError(), emitSuccess()
/// ═══════════════════════════════════════════════════════════
abstract class BaseCubit<T> extends Cubit<BaseState> {
  BaseCubit() : super(const InitialState());

  /// ═══════════════════════════════════════════════════════
  /// handleApiCall
  ///
  /// Executes an API call and handles:
  /// - Loading
  /// - Success
  /// - Error
  /// ═══════════════════════════════════════════════════════
  Future<void> handleApiCall<R>({
    required Future<ApiResponse<R>> Function() apiCall,
    required void Function(R? data) onSuccess,
    String? loadingMessage,
  }) async {
    // ─── 1. Loading ───
    emit(const LoadingState());

    // 2. Execute the API call.
    final response = await apiCall();

    // 3. Check the response.
    if (response.success) {
      // Success
      onSuccess(response.data);
    } else {
      // Failure
      emit(
        ErrorState(message: response.message, statusCode: response.statusCode),
      );
    }
  }

  /// ═══════════════════════════════════════════════════════
  /// Helpers
  /// ═══════════════════════════════════════════════════════
  void emitLoading() => emit(const LoadingState());

  void emitError(String message, {int? statusCode}) {
    emit(ErrorState(message: message, statusCode: statusCode));
  }

  void emitInitial() => emit(const InitialState());
}
