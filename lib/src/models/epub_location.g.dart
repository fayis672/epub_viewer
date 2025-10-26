// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epub_location.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EpubLocation _$EpubLocationFromJson(Map<String, dynamic> json) => EpubLocation(
  startCfi: json['startCfi'] as String,
  endCfi: json['endCfi'] as String,
  progress: (json['progress'] as num).toDouble(),
);

Map<String, dynamic> _$EpubLocationToJson(EpubLocation instance) =>
    <String, dynamic>{
      'startCfi': instance.startCfi,
      'endCfi': instance.endCfi,
      'progress': instance.progress,
    };
