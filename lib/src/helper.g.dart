// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'helper.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EpubChapter _$EpubChapterFromJson(Map<String, dynamic> json) => EpubChapter(
      title: json['title'] as String,
      href: json['href'] as String,
      id: json['id'] as String,
      subitems: (json['subitems'] as List<dynamic>)
          .map((e) => EpubChapter.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$EpubChapterToJson(EpubChapter instance) =>
    <String, dynamic>{
      'title': instance.title,
      'href': instance.href,
      'id': instance.id,
      'subitems': instance.subitems.map((e) => e.toJson()).toList(),
    };

EpubSearchResult _$EpubSearchResultFromJson(Map<String, dynamic> json) =>
    EpubSearchResult(
      cfi: json['cfi'] as String,
      excerpt: json['excerpt'] as String,
    );

Map<String, dynamic> _$EpubSearchResultToJson(EpubSearchResult instance) =>
    <String, dynamic>{
      'cfi': instance.cfi,
      'excerpt': instance.excerpt,
    };

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

EpubDisplaySettings _$EpubDisplaySettingsFromJson(Map<String, dynamic> json) =>
    EpubDisplaySettings(
      fontSize: (json['fontSize'] as num?)?.toInt() ?? 15,
      spread: $enumDecodeNullable(_$EpubSpreadEnumMap, json['spread']) ??
          EpubSpread.auto,
      flow: $enumDecodeNullable(_$EpubFlowEnumMap, json['flow']) ??
          EpubFlow.scrolled,
      allowScriptedContent: json['allowScriptedContent'] as bool? ?? false,
      defaultDirection: $enumDecodeNullable(
              _$EpubDefaultDirectionEnumMap, json['defaultDirection']) ??
          EpubDefaultDirection.ltr,
      snap: json['snap'] as bool? ?? false,
      manager: $enumDecodeNullable(_$EpubManagerEnumMap, json['manager']) ??
          EpubManager.continuous,
    );

Map<String, dynamic> _$EpubDisplaySettingsToJson(
        EpubDisplaySettings instance) =>
    <String, dynamic>{
      'fontSize': instance.fontSize,
      'spread': _$EpubSpreadEnumMap[instance.spread]!,
      'flow': _$EpubFlowEnumMap[instance.flow]!,
      'defaultDirection':
          _$EpubDefaultDirectionEnumMap[instance.defaultDirection]!,
      'allowScriptedContent': instance.allowScriptedContent,
      'manager': _$EpubManagerEnumMap[instance.manager]!,
      'snap': instance.snap,
    };

const _$EpubSpreadEnumMap = {
  EpubSpread.none: 'none',
  EpubSpread.always: 'always',
  EpubSpread.auto: 'auto',
};

const _$EpubFlowEnumMap = {
  EpubFlow.paginated: 'paginated',
  EpubFlow.scrolled: 'scrolled',
};

const _$EpubDefaultDirectionEnumMap = {
  EpubDefaultDirection.ltr: 'ltr',
  EpubDefaultDirection.rtl: 'rtl',
};

const _$EpubManagerEnumMap = {
  EpubManager.continuous: 'continuous',
};

EpubTextExtractRes _$EpubTextExtractResFromJson(Map<String, dynamic> json) =>
    EpubTextExtractRes(
      text: json['text'] as String?,
      cfiRange: json['cfiRange'] as String?,
    );

Map<String, dynamic> _$EpubTextExtractResToJson(EpubTextExtractRes instance) =>
    <String, dynamic>{
      'text': instance.text,
      'cfiRange': instance.cfiRange,
    };
