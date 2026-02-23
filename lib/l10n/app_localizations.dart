import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const supportedLocales = [Locale('en'), Locale('es')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  bool get _isEs => locale.languageCode.toLowerCase().startsWith('es');

  String get appTitle => _isEs ? "Visor Multi Cámara" : "Multi Camera Viewer";
  String get authLoginTitle => _isEs ? "Iniciar sesión" : "Login";
  String get authCreateAccountTitle =>
      _isEs ? "Crear cuenta" : "Create Account";
  String get authEmailLabel => _isEs ? "Correo" : "Email";
  String get authPasswordLabel => _isEs ? "Contraseña" : "Password";
  String get authConfirmPasswordLabel =>
      _isEs ? "Confirmar contraseña" : "Confirm Password";
  String get authLoginButton => _isEs ? "Entrar" : "Login";
  String get authCreateAccountButton =>
      _isEs ? "Crear cuenta" : "Create Account";
  String get authNoAccountRegister => _isEs
      ? "¿No tienes una cuenta? Regístrate"
      : "Don't have an account? Register";
  String get authAlreadyHaveAccount => _isEs
      ? "¿Ya tienes una cuenta? Inicia sesión"
      : "Already have an account? Log in";
  String get authEnterAsGuest =>
      _isEs ? "Entrar como invitado" : "Enter as Guest";
  String get authDebugResetLocalDataAction =>
      _isEs ? "Reiniciar datos locales (debug)" : "Reset local data (debug)";
  String get authDebugResetLocalDataTitle =>
      _isEs ? "Reiniciar datos locales" : "Reset local data";
  String get authDebugResetLocalDataDescription => _isEs
      ? "Esto borrará todos los proyectos, grupos y cámaras locales en este dispositivo. Solo para desarrollo."
      : "This will delete all local projects, groups, and cameras on this device. Development only.";
  String get authDebugResetLocalDataConfirm => _isEs ? "Reiniciar" : "Reset";
  String get authDebugResetLocalDataSuccess =>
      _isEs ? "Datos locales borrados." : "Local data cleared.";
  String get authMigrateGuestData => _isEs
      ? "Migrar datos de la sesión invitada"
      : "Migrate data from guest session";
  String get authSignInWithGoogle =>
      _isEs ? "Continuar con Google" : "Continue with Google";
  String get authSignInWithMicrosoft =>
      _isEs ? "Continuar con Microsoft" : "Continue with Microsoft";
  String get authOrContinueWith =>
      _isEs ? "O continúa con" : "Or continue with";
  String get authLinkRequiredTitle =>
      _isEs ? "Usa un método existente" : "Use an existing sign-in method";
  String get authUsePasswordToContinue =>
      _isEs ? "Usar correo y contraseña" : "Use email/password";
  String get authDismiss => _isEs ? "Cerrar" : "Dismiss";
  String get authMigrationConflictTitle =>
      _isEs ? "Esta cuenta ya tiene datos" : "This account already has data";
  String get authMigrationConflictDescription => _isEs
      ? "Esta cuenta ya tiene datos existentes. Al migrar, se agregará un nuevo proyecto con los datos de invitado. Si excedes la cuota de proyectos, tendrás que ampliar la cuota o sobrescribir un proyecto existente. ¿Deseas migrar?"
      : "This account already has existing data. Migrating will add guest data as a new project. If you exceed the project quota, you will need to increase the quota or overwrite an existing project. Do you want to migrate?";
  String get authMigrationConfirm => _isEs ? "Migrar" : "Migrate";
  String get authMigrationConflictSkip =>
      _isEs ? "No migrar" : "Skip migration";
  String get authMigrationProjectStrategyLabel =>
      _isEs ? "Estrategia del proyecto" : "Project strategy";
  String get authMigrationGroupStrategyLabel =>
      _isEs ? "Estrategia del grupo" : "Group strategy";
  String get authMigrationStrategyMerge => _isEs ? "Combinar" : "Merge";
  String get authMigrationStrategyMigrate => _isEs ? "Migrar" : "Migrate";
  String get authMigrationStrategyOverwrite =>
      _isEs ? "Sobrescribir" : "Overwrite";
  String get authMigrationStrategySkip => _isEs ? "Omitir" : "Skip";
  String get authMigrationStrategyLocalOnly =>
      _isEs ? "Solo datos invitados" : "Guest data only";
  String get authMigrationStrategyRemoteOnly =>
      _isEs ? "Solo datos remotos" : "Remote data only";
  String get authMigrationStrategyGroupOverwriteGuest =>
      _isEs ? "Sobrescribir con datos invitados" : "Overwrite with guest data";
  String get authMigrationStrategyGroupOverwriteRemote =>
      _isEs ? "Mantener datos remotos" : "Keep remote data";
  String get authMigrationNoDirectConflicts => _isEs
      ? "No se detectaron conflictos directos por ID, pero migrar agregará nuevos datos."
      : "No direct ID conflicts were found, but migrating will add new data.";
  String get authMigrationWizardStepProjects =>
      _isEs ? "Paso 1: Proyectos" : "Step 1: Projects";
  String get authMigrationWizardStepGroups =>
      _isEs ? "Paso 2: Grupos" : "Step 2: Groups";
  String get authMigrationWizardStepCameras =>
      _isEs ? "Paso 3: Cámaras" : "Step 3: Cameras";
  String get authMigrationTargetProjectLabel =>
      _isEs ? "Proyecto remoto objetivo" : "Target remote project";
  String get authMigrationTargetGroupLabel =>
      _isEs ? "Grupo remoto objetivo" : "Target remote group";
  String get authMigrationTargetCameraLabel =>
      _isEs ? "Cámara remota objetivo" : "Target remote camera";
  String get authMigrationCreateNewTarget =>
      _isEs ? "Crear nuevo en remoto" : "Create new in remote";
  String get authMigrationNoRemoteItems => _isEs
      ? "No hay datos remotos seleccionados para comparar."
      : "No selected remote data to compare.";
  String get authMigrationValidationIssuesTitle => _isEs
      ? "Resuelve conflictos de migración"
      : "Resolve migration conflicts";
  String get authMigrationStepBack => _isEs ? "Atrás" : "Back";
  String get authMigrationStepNext => _isEs ? "Siguiente" : "Next";

  String authMigrationProjectComparison(String localName, String remoteName) {
    if (_isEs) {
      return "Invitado: $localName\\nRemoto: $remoteName";
    }
    return "Guest: $localName\\nRemote: $remoteName";
  }

  String authMigrationProjectGroupsSummary(int localCount, int remoteCount) {
    if (_isEs) {
      return "Grupos invitado: $localCount • grupos remotos: $remoteCount";
    }
    return "Guest groups: $localCount • remote groups: $remoteCount";
  }

  String authMigrationGroupComparison(String localName, String remoteName) {
    if (_isEs) {
      return "Grupo invitado: $localName\\nGrupo remoto: $remoteName";
    }
    return "Guest group: $localName\\nRemote group: $remoteName";
  }

  String authMigrationGroupCamerasSummary(int localCount, int remoteCount) {
    if (_isEs) {
      return "Cámaras invitado: $localCount • cámaras remotas: $remoteCount";
    }
    return "Guest cameras: $localCount • remote cameras: $remoteCount";
  }

  String authLinkRequiredDescription(String email, String provider) {
    if (_isEs) {
      return "Ya existe una cuenta para $email. Inicia sesión con uno de los métodos existentes y luego vincularemos tu acceso con $provider.";
    }
    return "An account already exists for $email. Sign in using one of the existing methods first, then we will link your $provider sign-in.";
  }

  String authContinueWithProvider(String provider) {
    return _isEs ? "Continuar con $provider" : "Continue with $provider";
  }

  String get validationEmailRequired =>
      _isEs ? "El correo es obligatorio" : "Email required";
  String get validationInvalidEmail =>
      _isEs ? "Correo inválido" : "Invalid email";
  String get validationPasswordMinLength => _isEs
      ? "La contraseña debe tener al menos 6 caracteres"
      : "Password must be at least 6 characters";
  String get validationPasswordsDoNotMatch =>
      _isEs ? "Las contraseñas no coinciden" : "Passwords do not match";

  String get authErrorSignInFailed => _isEs
      ? "No se pudo iniciar sesión. Intenta de nuevo."
      : "Sign in failed. Please try again.";
  String get authErrorGuestSignInFailed =>
      _isEs ? "No se pudo entrar como invitado." : "Guest sign-in failed.";
  String get authErrorCancelled =>
      _isEs ? "Se canceló el inicio de sesión." : "Sign-in was cancelled.";
  String get authErrorInvalidCredentials =>
      _isEs ? "Credenciales inválidas." : "Invalid credentials.";
  String get authErrorEmailAlreadyInUse => _isEs
      ? "Este correo ya está registrado. Inicia sesión o usa otro correo."
      : "This email is already registered. Sign in or use a different email.";
  String get authErrorAccountExistsDifferentCredential => _isEs
      ? "Este correo ya usa otro método de inicio de sesión."
      : "This email already uses a different sign-in method.";
  String get authErrorCredentialAlreadyInUse => _isEs
      ? "Esta credencial ya está vinculada a otra cuenta."
      : "This credential is already linked to another account.";
  String get authErrorRequiresRecentLogin => _isEs
      ? "Vuelve a iniciar sesión para continuar."
      : "Please sign in again to continue.";
  String get authErrorNetwork => _isEs
      ? "Error de red. Verifica tu conexión e inténtalo de nuevo."
      : "Network error. Check your connection and retry.";
  String get authErrorPendingCredentialNotFound => _isEs
      ? "El token de vinculación expiró. Intenta iniciar sesión nuevamente."
      : "Linking token expired. Please retry sign-in.";
  String get authErrorLinkWithPasswordRequired => _isEs
      ? "Primero inicia con correo y contraseña; luego vuelve a intentar vincular."
      : "Use email/password first, then retry provider linking.";
  String get authErrorUnsupportedProvider => _isEs
      ? "Método de inicio de sesión no compatible."
      : "Unsupported sign-in method.";
  String get authErrorGeneric => _isEs
      ? "Ocurrió un error. Intenta de nuevo."
      : "Something went wrong. Please retry.";
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
