// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epub_theme.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EpubTheme _$EpubThemeFromJson(Map<String, dynamic> json) => EpubTheme(
  backgroundColor: const ColorConverter().fromJson(
    json['backgroundColor'] as String?,
  ),
  foregroundColor: const ColorConverter().fromJson(
    json['foregroundColor'] as String?,
  ),
  themeType: $enumDecode(_$EpubThemeTypeEnumMap, json['themeType']),
);

Map<String, dynamic> _$EpubThemeToJson(EpubTheme instance) => <String, dynamic>{
  'backgroundColor': const ColorConverter().toJson(instance.backgroundColor),
  'foregroundColor': const ColorConverter().toJson(instance.foregroundColor),
  'themeType': _$EpubThemeTypeEnumMap[instance.themeType]!,
};

const _$EpubThemeTypeEnumMap = {
  EpubThemeType.dark: 'dark',
  EpubThemeType.light: 'light',
  EpubThemeType.custom: 'custom',
};
