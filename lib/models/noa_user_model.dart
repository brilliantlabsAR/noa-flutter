class NoaUser {
  String email = "Not logged in";
  String plan = "";
  int tokensUsed = 0;
  int requestsUsed = 0;
  int maxTokens = 0;
  int maxRequests = 0;

  void update({
    required String email,
    required String plan,
    required int tokensUsed,
    required int requestsUsed,
    required int maxTokens,
    required int maxRequests,
  }) {
    this.email = email;
    this.plan = plan;
    this.tokensUsed = tokensUsed;
    this.requestsUsed = requestsUsed;
    this.maxTokens = maxTokens;
    this.maxRequests = maxRequests;
  }
}
