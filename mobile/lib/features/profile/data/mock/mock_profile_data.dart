import 'package:syntrace/core/models/user_model.dart';

class MockProfileData {
  static final Map<String, UserModel> profiles = {
    // خليكي متأكدة إن الـ ID ده مطابق للـ ID بتاع رودينا في الجراف
    'd1': const UserModel(
      id: 'd1',
      name: 'Rodaina Mohamed',
      email: 'rodaina@syntrace.com',
      role: UserRole.developer,
      tenantId: 'tenant-1',
    ),
    // خليكي متأكدة إن الـ ID ده مطابق للـ ID بتاع أحمد في الجراف
    'd2': const UserModel(
      id: 'd2',
      name: 'Ahmed Hassan',
      email: 'ahmed@syntrace.com',
      role: UserRole.developer,
      tenantId: 'tenant-1',
    ),
  };

  static UserModel getProfile(String id) {
    // لو الـ ID موجود، هيرجعه. لو مش موجود، هيعمل بروفايل وهمي بالـ ID ده
    if (profiles.containsKey(id)) {
      return profiles[id]!;
    }

    // عشان نمنع إنه يجيب رودينا بالغلط، لو الـ ID مش موجود هيظهر "Unknown Developer"
    return UserModel(
      id: id,
      name: 'Unknown Developer ($id)',
      email: 'unknown@syntrace.com',
      role: UserRole.developer,
      tenantId: 'tenant-1',
    );
  }

  static UserModel getProfileByName(String name) {
    // بيدور على الاسم اللي جاي من النود
    if (name.contains('Ahmed')) {
      return profiles['d2']!;
    }
    return profiles['d1']!; // بيرجع رودينا كـ Default
  }
}
