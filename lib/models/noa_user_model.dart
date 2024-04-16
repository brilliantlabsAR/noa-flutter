class NoaUser {
  String email = "Not logged in";
  String plan = "";
  int creditsUsed = 0;
  int maxCredits = 0;

  void update({
    required String email,
    required String plan,
    required int creditsUsed,
    required int maxCredits,
  }) {
    this.email = email;
    this.plan = plan;
    this.creditsUsed = creditsUsed;
    this.maxCredits = maxCredits;
  }
}
