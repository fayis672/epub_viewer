import 'package:json_annotation/json_annotation.dart';

part 'epub_location.g.dart';

@JsonSerializable(explicitToJson: true)
class EpubLocation {
  /// Start cfi string of the page
  String startCfi;

  /// End cfi string of the page
  String endCfi;

  /// Progress percentage of location, value between 0.0 and 1.0
  double progress;

  EpubLocation({
    required this.startCfi,
    required this.endCfi,
    required this.progress,
  });
  factory EpubLocation.fromJson(Map<String, dynamic> json) =>
      _$EpubLocationFromJson(json);
  Map<String, dynamic> toJson() => _$EpubLocationToJson(this);
}
