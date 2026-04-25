class QuestionResponse {
  final String question;
  final String answer;
  final bool isSkipped;
  final int responseTimeSeconds;

  QuestionResponse({
    required this.question,
    required this.answer,
    this.isSkipped = false,
    this.responseTimeSeconds = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'answer': answer,
      'isSkipped': isSkipped,
      'responseTimeSeconds': responseTimeSeconds,
    };
  }

  factory QuestionResponse.fromMap(Map<dynamic, dynamic> map) {
    return QuestionResponse(
      question: map['question'] ?? '',
      answer: map['answer'] ?? '',
      isSkipped: map['isSkipped'] ?? false,
      responseTimeSeconds: map['responseTimeSeconds'] ?? 0,
    );
  }
}
