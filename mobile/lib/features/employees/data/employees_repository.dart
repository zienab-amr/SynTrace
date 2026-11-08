import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/core/network/api_response.dart';
import 'models/employee_model.dart';

class EmployeesRepository {
  Future<ApiResponse<List<EmployeeModel>>> getAllEmployees() async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.allEmployees,
        queryParameters: {'Role': ''},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> list = [];
        if (data is List) {
          list = data;
        } else if (data is Map && data['data'] is List) {
          list = data['data'];
        }

        final employees = list
            .whereType<Map<String, dynamic>>()
            .map((e) => EmployeeModel.fromJson(e))
            .toList();

        return ApiResponse.success(data: employees);
      }

      return ApiResponse.failure(
        message: 'Failed to load employees (${response.statusCode})',
      );
    } catch (e) {
      return ApiResponse.failure(message: 'Error: $e');
    }
  }

  Future<ApiResponse<bool>> createEmployee({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phoneNumber,
    required String role,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.createEmployee,
        data: {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'password': password,
          'phoneNumber': phoneNumber,
          'role': role,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse.success(data: true);
      }
      return ApiResponse.failure(
        message: 'Failed to create employee (${response.statusCode})',
      );
    } catch (e) {
      return ApiResponse.failure(message: 'Error: $e');
    }
  }

  Future<ApiResponse<bool>> deleteEmployee(String employeeId) async {
    try {
      final response = await ApiClient.instance.delete(
        ApiEndpoints.deleteEmployee,
        data: {'employeeId': employeeId},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse.success(data: true);
      }
      return ApiResponse.failure(
        message: 'Failed to delete employee (${response.statusCode})',
      );
    } catch (e) {
      return ApiResponse.failure(message: 'Error: $e');
    }
  }

  Future<ApiResponse<bool>> changeRole(
    String employeeId,
    String newRole,
  ) async {
    try {
      final response = await ApiClient.instance.put(
        ApiEndpoints.changeRole,
        data: {'employeeId': employeeId, 'newRole': newRole},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse.success(data: true);
      }
      return ApiResponse.failure(
        message: 'Failed to change role (${response.statusCode})',
      );
    } catch (e) {
      return ApiResponse.failure(message: 'Error: $e');
    }
  }
}
