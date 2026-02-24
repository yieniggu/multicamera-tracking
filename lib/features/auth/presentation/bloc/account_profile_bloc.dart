import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/get_contact_email.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/account_profile_event.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/account_profile_state.dart';
import 'package:multicamera_tracking/features/user_profile/domain/use_cases/get_current_user_profile.dart';
import 'package:multicamera_tracking/features/user_profile/domain/use_cases/update_current_user_profile.dart';

class AccountProfileBloc
    extends Bloc<AccountProfileEvent, AccountProfileState> {
  final GetCurrentUserProfileUseCase getCurrentUserProfileUseCase;
  final UpdateCurrentUserProfileUseCase updateCurrentUserProfileUseCase;
  final GetContactEmailUseCase getContactEmailUseCase;

  AccountProfileBloc({
    required this.getCurrentUserProfileUseCase,
    required this.updateCurrentUserProfileUseCase,
    required this.getContactEmailUseCase,
  }) : super(const AccountProfileState.initial()) {
    on<AccountProfileRequested>(_onRequested);
    on<AccountProfileFirstNameChanged>(_onFirstNameChanged);
    on<AccountProfileLastNameChanged>(_onLastNameChanged);
    on<AccountProfilePhoneChanged>(_onPhoneChanged);
    on<AccountProfileSaveSubmitted>(_onSaveSubmitted);
    on<AccountProfileFeedbackCleared>(_onFeedbackCleared);
  }

  Future<void> _onRequested(
    AccountProfileRequested event,
    Emitter<AccountProfileState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoading: true,
        lastErrorMessageKey: null,
        lastSuccessMessageKey: null,
      ),
    );

    try {
      final profile = await getCurrentUserProfileUseCase();
      final contactEmail = await getContactEmailUseCase();
      if (profile == null) {
        emit(
          state.copyWith(
            isLoading: false,
            lastErrorMessageKey: 'profile.error.load',
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          isLoading: false,
          email: (profile.email ?? contactEmail ?? '').trim(),
          firstName: profile.firstName,
          lastName: profile.lastName,
          phoneNumber: profile.phoneNumber ?? '',
          initialFirstName: profile.firstName,
          initialLastName: profile.lastName,
          initialPhoneNumber: profile.phoneNumber ?? '',
          lastErrorMessageKey: null,
          lastSuccessMessageKey: null,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          lastErrorMessageKey: 'profile.error.load',
          lastSuccessMessageKey: null,
        ),
      );
    }
  }

  void _onFirstNameChanged(
    AccountProfileFirstNameChanged event,
    Emitter<AccountProfileState> emit,
  ) {
    emit(
      state.copyWith(
        firstName: event.value,
        lastErrorMessageKey: null,
        lastSuccessMessageKey: null,
      ),
    );
  }

  void _onLastNameChanged(
    AccountProfileLastNameChanged event,
    Emitter<AccountProfileState> emit,
  ) {
    emit(
      state.copyWith(
        lastName: event.value,
        lastErrorMessageKey: null,
        lastSuccessMessageKey: null,
      ),
    );
  }

  void _onPhoneChanged(
    AccountProfilePhoneChanged event,
    Emitter<AccountProfileState> emit,
  ) {
    emit(
      state.copyWith(
        phoneNumber: event.value,
        lastErrorMessageKey: null,
        lastSuccessMessageKey: null,
      ),
    );
  }

  Future<void> _onSaveSubmitted(
    AccountProfileSaveSubmitted event,
    Emitter<AccountProfileState> emit,
  ) async {
    if (!state.canSave) {
      if (!state.isFirstNameValid) {
        emit(
          state.copyWith(
            lastErrorMessageKey: 'profile.error.firstNameRequired',
            lastSuccessMessageKey: null,
          ),
        );
      } else if (!state.isPhoneValid) {
        emit(
          state.copyWith(
            lastErrorMessageKey: 'profile.error.phoneInvalid',
            lastSuccessMessageKey: null,
          ),
        );
      }
      return;
    }

    emit(
      state.copyWith(
        isSaving: true,
        lastErrorMessageKey: null,
        lastSuccessMessageKey: null,
      ),
    );

    try {
      final normalizedPhone = normalizePhone(state.phoneNumber);
      await updateCurrentUserProfileUseCase(
        firstName: state.firstName.trim(),
        lastName: state.lastName.trim(),
        phoneNumber: normalizedPhone,
      );

      emit(
        state.copyWith(
          isSaving: false,
          firstName: state.firstName.trim(),
          lastName: state.lastName.trim(),
          phoneNumber: normalizedPhone ?? '',
          initialFirstName: state.firstName.trim(),
          initialLastName: state.lastName.trim(),
          initialPhoneNumber: normalizedPhone ?? '',
          lastErrorMessageKey: null,
          lastSuccessMessageKey: 'profile.success.saved',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isSaving: false,
          lastErrorMessageKey: 'profile.error.save',
          lastSuccessMessageKey: null,
        ),
      );
    }
  }

  void _onFeedbackCleared(
    AccountProfileFeedbackCleared event,
    Emitter<AccountProfileState> emit,
  ) {
    emit(
      state.copyWith(lastErrorMessageKey: null, lastSuccessMessageKey: null),
    );
  }
}
