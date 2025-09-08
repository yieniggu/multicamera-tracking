import 'package:multicamera_tracking/features/auth/domain/entities/access_role.dart';

AccessRole parseAccessRole(String? role) {
  switch (role) {
    case 'admin':
      return AccessRole.admin;
    case 'editor':
      return AccessRole.editor;
    case 'viewer':
    default:
      return AccessRole.viewer;
  }
}
