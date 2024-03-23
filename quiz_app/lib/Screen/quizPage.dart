import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:quiz_app/Screen/mainMenu.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuestionAnswerPage extends StatefulWidget {
  const QuestionAnswerPage({Key? key}) : super(key: key);

  @override
  _QuestionAnswerPageState createState() => _QuestionAnswerPageState();
}

class _QuestionAnswerPageState extends State<QuestionAnswerPage>
    with SingleTickerProviderStateMixin {
  late SharedPreferences _prefs;
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _isAnswering = true;
  late int _highScore;
  Timer? _timer;
  double _progressValue = 1.0;
  late Animation<Color?> _progressColorAnimation;
  late AnimationController _progressColorController;

  @override
  void initState() {
    super.initState();
    _progressColorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _progressColorAnimation = ColorTween(
      begin: Colors.grey[300],
      end: Colors.green,
    ).animate(_progressColorController);
    _fetchQuestions();
    _loadHighScore();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressColorController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuestions() async {
    try {
      final response = await http.get(
        Uri.parse('https://herosapp.nyc3.digitaloceanspaces.com/quiz.json'),
      );
      if (response.statusCode == 200) {
        final List<Map<String, dynamic>> allQuestions =
            List<Map<String, dynamic>>.from(
          json.decode(response.body)['questions'],
        );

        // Filter out the undesired part of the JSON data
        _questions = allQuestions
            .where((question) =>
                question['question'] !=
                "Was ist <u>keine</u> Leitlinie von CHECK24?")
            .toList();

        _questions.shuffle(); // Shuffle questions randomly
      } else {
        throw Exception(
            'Failed to load questions'); // Throw an exception for failed HTTP request
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching questions: $e');
      }
      // Handle error appropriately (e.g., show error message to user)
    }
  }

  Future<void> _loadHighScore() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = _prefs.getInt('high_score') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    await _prefs.setInt('high_score', _highScore);
  }

  void _startTimer() {
    const duration = Duration(seconds: 5);
    _timer = Timer.periodic(duration, (timer) {
      setState(() {
        _progressValue -= 1 / (duration.inMilliseconds / 1000);
      });
      if (_progressValue <= 0) {
        _timer?.cancel();
        _answerQuestion(-1); // Timeout
      }
    });
    _progressColorController.forward(from: 0.0);
  }

  void _answerQuestion(int selectedAnswerIndex) {
    if (!_isAnswering) return;

    setState(() {
      _isAnswering = false;
    });

    _timer?.cancel();

    final question = _questions[_currentQuestionIndex];
    final answers = List<String>.from(question['answers'].values);
    final correctAnswerKey = question['correctAnswer'];
    final correctAnswerIndex =
        question['answers'].keys.toList().indexOf(correctAnswerKey);

    Fluttertoast.cancel();

    if (selectedAnswerIndex != -1 &&
        selectedAnswerIndex == correctAnswerIndex) {
      Fluttertoast.showToast(
        msg: "Correct Answer!",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.green.withOpacity(0.8),
      );
      setState(() {
        _score += question['score'] as int;
      });
    } else {
      Fluttertoast.showToast(
        msg: "Incorrect Answer!",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.red.withOpacity(0.8),
      );
      final correctAnswer = correctAnswerIndex != -1
          ? answers[correctAnswerIndex]
          : "Answer not found";
      Fluttertoast.showToast(
        msg: "Correct Answer: $correctAnswer",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.green.withOpacity(0.8),
      );
    }

    // Transition to next question after a delay
    _transitionToNextQuestion();
  }

  Future<void> _transitionToNextQuestion() async {
    // Show loading animation for 2 seconds
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: Center(
          child: LoadingAnimationWidget.staggeredDotsWave(
            color: Colors.lightBlue,
            size: 100,
          ),
        ),
      ),
    );

    // Wait for 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    // ignore: use_build_context_synchronously
    Navigator.pop(context);

    // Transition to the next question
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _isAnswering = true;
        _progressValue = 1.0; // Reset progress
        _startTimer(); // Start timer for next question
      });
    } else {
      // Quiz completed
      _showEndOfGameDialog();
    }
  }

  void _showEndOfGameDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quiz Complete!'),
        content: Text('Your Score: $_score'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                ModalRoute.withName('/main_menu'),
              );
            },
            child: const Text('Return to Main Menu'),
          ),
        ],
      ),
    );

    // Update high score
    if (_score > _highScore) {
      setState(() {
        _highScore = _score;
      });
      _saveHighScore();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        body: Center(
          child: LoadingAnimationWidget.staggeredDotsWave(
            color: Colors.green,
            size: 100,
          ),
        ),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final answers = List<String>.from(question['answers'].values);
    //answers.shuffle(); // Shuffle answers randomly

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Question ${_currentQuestionIndex + 1}',
          style: const TextStyle(
            // fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10),
          child: AnimatedBuilder(
            animation: _progressColorAnimation,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: _progressValue,
                backgroundColor: Colors.grey[300],
                valueColor: _progressColorAnimation,
              );
            },
          ),

          // child: LinearProgressIndicator(
          //   value: _progressValue,
          //   backgroundColor: Colors.grey[300],
          //   valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          // ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildScoreWidget(), // Current score widget
            Card(
              shadowColor: Colors.white.withOpacity(0.3),
              color: Colors.white,
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question['question'],
                      style: const TextStyle(fontSize: 18),
                    ),
                    if (question['questionImageUrl'] != null)
                      Center(
                        child: Image.network(
                          question['questionImageUrl'],
                          height: 200,
                          fit: BoxFit.fill,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Score: ${question['score']}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(
                answers.length,
                (index) {
                  String optionKey = String.fromCharCode(
                      65 + index); // Convert index to alphabet
                  return ElevatedButton(
                    onPressed: _isAnswering
                        ? () {
                            _answerQuestion(index);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blue,
                    ),
                    child: Text(
                        '$optionKey : ${answers[index]}'), // Show option key with answer
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        'Current Score: $_score',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}
