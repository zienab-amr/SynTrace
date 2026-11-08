import 'package:syntrace/core/state/base_state.dart';
import 'package:syntrace/features/developers/data/models/developer_model.dart';

abstract class DevelopersState extends BaseState {
  const DevelopersState();
}

class DevelopersInitial extends DevelopersState {}

class DevelopersLoading extends DevelopersState {}

class DevelopersLoaded extends DevelopersState {
  final List<DeveloperModel> developers;
  const DevelopersLoaded(this.developers);

  @override
  List<Object?> get props => [developers];
}

class DevelopersError extends DevelopersState {
  final String message;
  const DevelopersError(this.message);

  @override
  List<Object?> get props => [message];
}
