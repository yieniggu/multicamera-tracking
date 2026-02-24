import 'package:equatable/equatable.dart';

class AccountProfileState extends Equatable {
  static const _unset = Object();

  final bool isLoading;
  final bool isSaving;
  final String email;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String initialFirstName;
  final String initialLastName;
  final String initialPhoneNumber;
  final String? lastErrorMessageKey;
  final String? lastSuccessMessageKey;

  const AccountProfileState({
    required this.isLoading,
    required this.isSaving,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.initialFirstName,
    required this.initialLastName,
    required this.initialPhoneNumber,
    this.lastErrorMessageKey,
    this.lastSuccessMessageKey,
  });

  const AccountProfileState.initial()
    : isLoading = false,
      isSaving = false,
      email = '',
      firstName = '',
      lastName = '',
      phoneNumber = '',
      initialFirstName = '',
      initialLastName = '',
      initialPhoneNumber = '',
      lastErrorMessageKey = null,
      lastSuccessMessageKey = null;

  String? get normalizedPhone => normalizePhone(phoneNumber);

  bool get isFirstNameValid => firstName.trim().isNotEmpty;

  bool get isPhoneValid =>
      phoneNumber.trim().isEmpty || normalizePhone(phoneNumber) != null;

  bool get hasChanges {
    return firstName.trim() != initialFirstName.trim() ||
        lastName.trim() != initialLastName.trim() ||
        normalizePhone(phoneNumber) != normalizePhone(initialPhoneNumber);
  }

  bool get canSave =>
      !isLoading && !isSaving && isFirstNameValid && isPhoneValid && hasChanges;

  AccountProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? initialFirstName,
    String? initialLastName,
    String? initialPhoneNumber,
    Object? lastErrorMessageKey = _unset,
    Object? lastSuccessMessageKey = _unset,
  }) {
    return AccountProfileState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      initialFirstName: initialFirstName ?? this.initialFirstName,
      initialLastName: initialLastName ?? this.initialLastName,
      initialPhoneNumber: initialPhoneNumber ?? this.initialPhoneNumber,
      lastErrorMessageKey: identical(lastErrorMessageKey, _unset)
          ? this.lastErrorMessageKey
          : lastErrorMessageKey as String?,
      lastSuccessMessageKey: identical(lastSuccessMessageKey, _unset)
          ? this.lastSuccessMessageKey
          : lastSuccessMessageKey as String?,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isSaving,
    email,
    firstName,
    lastName,
    phoneNumber,
    initialFirstName,
    initialLastName,
    initialPhoneNumber,
    lastErrorMessageKey,
    lastSuccessMessageKey,
  ];
}

String? normalizePhone(String? input) {
  final value = input?.trim() ?? '';
  if (value.isEmpty) return null;

  final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  if (!RegExp(r'^\+?\d+$').hasMatch(cleaned)) {
    return null;
  }

  final hasPlus = cleaned.startsWith('+');
  final digits = cleaned.replaceAll('+', '');
  if (!RegExp(r'^\d{7,15}$').hasMatch(digits)) {
    return null;
  }

  return hasPlus ? '+$digits' : digits;
}
