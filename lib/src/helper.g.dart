// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'helper.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EpubChapter _$EpubChapterFromJson(Map<String, dynamic> json) => EpubChapter(
      title: json['title'] as String?,
      href: json['href'] as String,
    );

Map<String, dynamic> _$EpubChapterToJson(EpubChapter instance) =>
    <String, dynamic>{
      'title': instance.title,
      'href': instance.href,
    };

EpubSearchResult _$EpubSearchResultFromJson(Map<String, dynamic> json) =>
    EpubSearchResult(
      cfi: json['cfi'] as String?,
      excerpt: json['excerpt'] as String?,
    );

Map<String, dynamic> _$EpubSearchResultToJson(EpubSearchResult instance) =>
    <String, dynamic>{
      'cfi': instance.cfi,
      'excerpt': instance.excerpt,
    };
