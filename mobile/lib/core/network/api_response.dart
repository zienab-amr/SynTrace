class ApiResponse<T>
{
  final bool success;
  final String message;
  final T? data;
  final List<String>? errors;
  final int? statusCode;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors,
    this.statusCode,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    T Function(dynamic)? fromData,
    int? statusCode,
  }) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null && fromData != null
          ? fromData(json['data'])
          : json['data'] as T?,
      errors: json['errors'] != null
          ? List<String>.from(json['errors'] as List)
          : null,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.success({
    required T data,
    String message = 'Success',
    int? statusCode,
  }) {
    return ApiResponse<T>(
      success: true,
      message: message,
      data: data,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.failure({
    required String message,
    List<String>? errors,
    int? statusCode,
  }) {
    return ApiResponse<T>(
      success: false,
      message: message,
      errors: errors,
      statusCode: statusCode,
    );
  }

  bool get hasData => data != null;

  bool get hasErrors => errors != null && errors!.isNotEmpty;

  @override
  String toString() {
    return 'ApiResponse(success: $success, message: $message, '
        'data: $data, errors: $errors, statusCode: $statusCode)';
  }
}