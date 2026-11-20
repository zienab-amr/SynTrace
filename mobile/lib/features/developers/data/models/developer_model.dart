class DeveloperModel {
  final String id;
  final String name;
  final String role;
  final String email;

  final String team;
  final bool isOverloaded;
  final int commits;
  final int prs;
  final int openTasks;
  final int velocity;
  final int healthPercent;
  final List<String> techStack;
  final String initials;

  DeveloperModel({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    this.team = 'Engineering',
    this.isOverloaded = false,
    this.commits = 0,
    this.prs = 0,
    this.openTasks = 0,
    this.velocity = 0,
    this.healthPercent = 100,
    this.techStack = const ['Flutter'],
    required this.initials,
  });

  factory DeveloperModel.fromJson(Map<String, dynamic> json) {
    final firstName = json['firstName']?.toString() ?? '';
    final lastName = json['lastName']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();

    String initials = '';
    if (firstName.isNotEmpty) initials += firstName[0];
    if (lastName.isNotEmpty) initials += lastName[0];
    if (initials.isEmpty) initials = '?';

    return DeveloperModel(
      id: json['id']?.toString() ?? json['employeeId']?.toString() ?? '',
      name: fullName.isEmpty ? 'Unknown' : fullName,
      role:
          json['role']?.toString() ??
          json['discriminator']?.toString() ??
          'Developer',
      email: json['email']?.toString() ?? '',
      initials: initials.toUpperCase(),
    );
  }
}
