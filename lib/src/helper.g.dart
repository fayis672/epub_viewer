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
      startCfi: json['startCfi'] as String?,
      endCfi: json['endCfi'] as String?,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
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
          EpubFlow.paginated,
      allowScriptedContent: json['allowScriptedContent'] as bool? ?? false,
      defaultDirection: $enumDecodeNullable(
              _$EpubDefaultDirectionEnumMap, json['defaultDirection']) ??
          EpubDefaultDirection.ltr,
      snap: json['snap'] as bool? ?? true,
      useSnapAnimationAndroid:
          json['useSnapAnimationAndroid'] as bool? ?? false,
      manager: $enumDecodeNullable(_$EpubManagerEnumMap, json['manager']) ??
          EpubManager.continuous,
      theme: EpubDisplaySettings._themeFromJson(
          json['theme'] as Map<String, dynamic>?),
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
      'useSnapAnimationAndroid': instance.useSnapAnimationAndroid,
      if (EpubDisplaySettings._themeToJson(instance.theme) case final value?)
        'theme': value,
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

EpubBookmark _$EpubBookmarkFromJson(Map<String, dynamic> json) => EpubBookmark(
      cfi: json['cfi'] as String,
      title: json['title'] as String,
    );

Map<String, dynamic> _$EpubBookmarkToJson(EpubBookmark instance) =>
    <String, dynamic>{
      'cfi': instance.cfi,
      'title': instance.title,
    };

EpubMetadata _$EpubMetadataFromJson(Map<String, dynamic> json) => EpubMetadata(
      identifier: json['identifier'] as String?,
      title: json['title'] as String?,
      creator: json['creator'] as String?,
      publisher: json['publisher'] as String?,
      language: json['language'] as String?,
      pubdate: json['pubdate'] as String?,
      modifiedDate: json['modifiedDate'] as String?,
      rights: json['rights'] as String?,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$EpubMetadataToJson(EpubMetadata instance) =>
    <String, dynamic>{
      'identifier': instance.identifier,
      'title': instance.title,
      'creator': instance.creator,
      'publisher': instance.publisher,
      'language': instance.language,
      'pubdate': instance.pubdate,
      'modifiedDate': instance.modifiedDate,
      'rights': instance.rights,
      'description': instance.description,
    };
