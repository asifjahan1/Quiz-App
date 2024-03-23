import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuestionAnswerPage extends StatefulWidget {
  const QuestionAnswerPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _QuestionAnswerPageState createState() => _QuestionAnswerPageState();
}

class _QuestionAnswerPageState extends State<QuestionAnswerPage> {
  late SharedPreferences _prefs;
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _isAnswering = true;
  late int _highScore;
  Timer? _timer;
  double _progressValue = 1.0;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
    _loadHighScore();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchQuestions() async {
    try {
      final response = await http.get(
        Uri.parse('https://herosapp.nyc3.digitaloceanspaces.com/quiz.json'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _questions = List<Map<String, dynamic>>.from(
            json.decode(response.body)['questions'],
          );
          _questions.shuffle(); // Shuffle questions randomly
        });
      } else {
        throw Exception('Failed to load questions');
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
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      setState(() {
        _score += question['score'] as int;
      });
    } else {
      Fluttertoast.showToast(
        msg: "Incorrect Answer!",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.white,
        textColor: Colors.red,
      );
      final correctAnswer = correctAnswerIndex != -1
          ? answers[correctAnswerIndex]
          : "Answer not found";
      Fluttertoast.showToast(
        msg: "Correct Answer: $correctAnswer",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.white,
        textColor: Colors.green,
      );
    }

    Future.delayed(const Duration(seconds: 2), () {
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
    });
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
              Navigator.pop(context); // Close dialog
              // Navigate back to main menu or perform any other action
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
            color: Colors.white,
            size: 200,
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
          child: LinearProgressIndicator(
            value: _progressValue,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          ),
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
