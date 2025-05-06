import 'dart:convert';

import 'package:flutter/material.dart';

class Highlight {
  final String cfi;
  final String text;
  final Color color;
  final double opacity;

  Highlight({
    required this.cfi,
    required this.text,
    this.color = Colors.yellow,
    this.opacity = 0.3,
  });

  Map<String, dynamic> toJson() {
    return {
      'cfi': cfi,
      'text': text,
      'color': color.value,
      'opacity': opacity,
    };
  }

  String get asString => jsonEncode(toJson());

  factory Highlight.fromString(String json) =>
      Highlight.fromJson(jsonDecode(json));

  factory Highlight.fromJson(Map<String, dynamic> json) {
    return Highlight(
      cfi: json['cfi'],
      text: json['text'],
      color: Color(json['color']),
      opacity: json['opacity'],
    );
  }
}
