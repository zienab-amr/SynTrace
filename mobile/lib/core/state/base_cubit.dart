import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/network/api_response.dart';
import 'package:syntrace/core/state/base_state.dart';

/// ═══════════════════════════════════════════════════════════
/// Base Cubit
/// 
/// الـ Parent لكل الـ Cubits في التطبيق
/// بيوفرلك:
/// - handleApiCall(): بيتعامل مع كل حاجة (Loading, Success, Error)
/// - emitLoading(), emitError(), emitSuccess()
/// ═══════════════════════════════════════════════════════════
abstract class BaseCubit<T> extends Cubit<BaseState> {
  BaseCubit() : super(const InitialState());

  /// ═══════════════════════════════════════════════════════
  /// handleApiCall
  /// 
  /// الـ Helper الأساسي: بينادي على الـ API وبيتعامل مع:
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

    // ─── 2. نادي على الـ API ───
    final response = await apiCall();

    // ─── 3. تحقق من النتيجة ───
    if (response.success) {
      // ✅ نجاح
      onSuccess(response.data);
    } else {
      // ❌ فشل
      emit(ErrorState(
        message: response.message,
        statusCode: response.statusCode,
      ));
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