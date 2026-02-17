abstract class AppMode {
  bool get isRemote;
  bool get isGuest;
  bool get isTrial;

  void enterGuest();
  void enterRemote();
}
