import 'package:flutter/material.dart';

class ErrorProvider extends ChangeNotifier {
  String? _errorMessage;
  bool _isVisible = false;

  String? get errorMessage => _errorMessage;
  bool get isVisible => _isVisible;

  void showError(String message) {
    _errorMessage = message;
    _isVisible = true;
    notifyListeners();

    // Auto-hide after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      hideError();
    });
  }

  void hideError() {
    _errorMessage = null;
    _isVisible = false;
    notifyListeners();
  }
}
