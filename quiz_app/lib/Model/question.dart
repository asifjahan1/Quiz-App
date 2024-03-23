class Question {
  final String question;
  final Map<String, String> answers;
  final String? questionImageUrl;
  final String correctAnswer;
  final int score;

  Question({
    required this.question,
    required this.answers,
    this.questionImageUrl,
    required this.correctAnswer,
    required this.score,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      question: json['question'],
      answers: Map<String, String>.from(json['answers']),
      questionImageUrl: json['questionImageUrl'],
      correctAnswer: json['correctAnswer'],
      score: json['score'],
    );
  }
}
