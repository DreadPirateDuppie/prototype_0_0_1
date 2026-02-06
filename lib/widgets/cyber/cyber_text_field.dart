import 'package:flutter/material.dart';

class CyberTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final IconData? prefixIcon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const CyberTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint = '',
    this.obscureText = false,
    this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
  });

  @override
  State<CyberTextField> createState() => _CyberTextFieldState();
}

class _CyberTextFieldState extends State<CyberTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matrixGreen = const Color(0xFF00FF41);
    final darkGreen = const Color(0xFF003300);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5), // Fixed: withOpacity
        border: Border(
          bottom: BorderSide(
            color: _hasFocus ? matrixGreen : Colors.grey.withOpacity(0.5), // Fixed
            width: _hasFocus ? 2.0 : 1.0,
          ),
        ),
        boxShadow: _hasFocus
            ? [
                BoxShadow(
                  color: matrixGreen.withOpacity(0.2), // Fixed
                  blurRadius: 15,
                  spreadRadius: -5,
                  offset: const Offset(0, 10),
                )
              ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        style: TextStyle(
          color: matrixGreen,
          fontFamily: 'monospace',
          fontSize: 16,
        ),
        cursorColor: matrixGreen,
        decoration: InputDecoration(
          labelText: widget.label.toUpperCase(),
          labelStyle: TextStyle(
            color: _hasFocus ? matrixGreen : Colors.grey,
            fontFamily: 'monospace',
            letterSpacing: 1.0,
          ),
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: darkGreen,
            fontFamily: 'monospace',
          ),
          prefixIcon: widget.prefixIcon != null
              ? Icon(
                  widget.prefixIcon,
                  color: _hasFocus ? matrixGreen : Colors.grey,
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16, // Comfortable touch target
          ),
          errorStyle: const TextStyle(
            color: Color(0xFFFF4444), // Neon Red
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
        validator: widget.validator,
        onChanged: widget.onChanged,
      ),
    );
  }
}
