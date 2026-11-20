import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/features/developers/data/models/developer_model.dart';
import 'developers_state.dart';

class DevelopersCubit extends Cubit<DevelopersState> {
  DevelopersCubit() : super(DevelopersInitial());

  Future<void> loadDevelopers() async {
    emit(DevelopersLoading());

    try {
      final response = await ApiClient.instance.get(
        '${ApiEndpoints.allEmployees}?Role=',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final developers = data
            .map((json) => DeveloperModel.fromJson(json))
            .toList();
        emit(DevelopersLoaded(developers));
      } else {
        emit(const DevelopersError('Failed to load developers from server.'));
      }
    } catch (e) {
      print('Error loading developers: $e');
      emit(DevelopersError('Error connecting to server: $e'));
    }
  }
}
