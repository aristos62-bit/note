// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAppSettingsCollection on Isar {
  IsarCollection<AppSettings> get appSettings => this.collection();
}

const AppSettingsSchema = CollectionSchema(
  name: r'AppSettings',
  id: -5633561779022347008,
  properties: {
    r'accentColor': PropertySchema(
      id: 0,
      name: r'accentColor',
      type: IsarType.string,
    ),
    r'autoSave': PropertySchema(
      id: 1,
      name: r'autoSave',
      type: IsarType.bool,
    ),
    r'autoSaveIntervalSeconds': PropertySchema(
      id: 2,
      name: r'autoSaveIntervalSeconds',
      type: IsarType.long,
    ),
    r'confirmBeforeDelete': PropertySchema(
      id: 3,
      name: r'confirmBeforeDelete',
      type: IsarType.bool,
    ),
    r'defaultView': PropertySchema(
      id: 4,
      name: r'defaultView',
      type: IsarType.string,
      enumMap: _AppSettingsdefaultViewEnumValueMap,
    ),
    r'defaultWorkspaceId': PropertySchema(
      id: 5,
      name: r'defaultWorkspaceId',
      type: IsarType.long,
    ),
    r'fontScale': PropertySchema(
      id: 6,
      name: r'fontScale',
      type: IsarType.double,
    ),
    r'hasCompletedOnboarding': PropertySchema(
      id: 7,
      name: r'hasCompletedOnboarding',
      type: IsarType.bool,
    ),
    r'itemTypeColorsJson': PropertySchema(
      id: 8,
      name: r'itemTypeColorsJson',
      type: IsarType.string,
    ),
    r'language': PropertySchema(
      id: 9,
      name: r'language',
      type: IsarType.string,
      enumMap: _AppSettingslanguageEnumValueMap,
    ),
    r'lastSyncAt': PropertySchema(
      id: 10,
      name: r'lastSyncAt',
      type: IsarType.dateTime,
    ),
    r'notificationsEnabled': PropertySchema(
      id: 11,
      name: r'notificationsEnabled',
      type: IsarType.bool,
    ),
    r'preferredFolderId': PropertySchema(
      id: 12,
      name: r'preferredFolderId',
      type: IsarType.long,
    ),
    r'showArchivedItems': PropertySchema(
      id: 13,
      name: r'showArchivedItems',
      type: IsarType.bool,
    ),
    r'showDeletedItems': PropertySchema(
      id: 14,
      name: r'showDeletedItems',
      type: IsarType.bool,
    ),
    r'soundEnabled': PropertySchema(
      id: 15,
      name: r'soundEnabled',
      type: IsarType.bool,
    ),
    r'syncEnabled': PropertySchema(
      id: 16,
      name: r'syncEnabled',
      type: IsarType.bool,
    ),
    r'syncIntervalMinutes': PropertySchema(
      id: 17,
      name: r'syncIntervalMinutes',
      type: IsarType.long,
    ),
    r'syncOnWifiOnly': PropertySchema(
      id: 18,
      name: r'syncOnWifiOnly',
      type: IsarType.bool,
    ),
    r'theme': PropertySchema(
      id: 19,
      name: r'theme',
      type: IsarType.string,
      enumMap: _AppSettingsthemeEnumValueMap,
    ),
    r'updatedAt': PropertySchema(
      id: 20,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'vibrationEnabled': PropertySchema(
      id: 21,
      name: r'vibrationEnabled',
      type: IsarType.bool,
    )
  },
  estimateSize: _appSettingsEstimateSize,
  serialize: _appSettingsSerialize,
  deserialize: _appSettingsDeserialize,
  deserializeProp: _appSettingsDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _appSettingsGetId,
  getLinks: _appSettingsGetLinks,
  attach: _appSettingsAttach,
  version: '3.1.0+1',
);

int _appSettingsEstimateSize(
  AppSettings object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.accentColor;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.defaultView.name.length * 3;
  {
    final value = object.itemTypeColorsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.language.name.length * 3;
  bytesCount += 3 + object.theme.name.length * 3;
  return bytesCount;
}

void _appSettingsSerialize(
  AppSettings object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accentColor);
  writer.writeBool(offsets[1], object.autoSave);
  writer.writeLong(offsets[2], object.autoSaveIntervalSeconds);
  writer.writeBool(offsets[3], object.confirmBeforeDelete);
  writer.writeString(offsets[4], object.defaultView.name);
  writer.writeLong(offsets[5], object.defaultWorkspaceId);
  writer.writeDouble(offsets[6], object.fontScale);
  writer.writeBool(offsets[7], object.hasCompletedOnboarding);
  writer.writeString(offsets[8], object.itemTypeColorsJson);
  writer.writeString(offsets[9], object.language.name);
  writer.writeDateTime(offsets[10], object.lastSyncAt);
  writer.writeBool(offsets[11], object.notificationsEnabled);
  writer.writeLong(offsets[12], object.preferredFolderId);
  writer.writeBool(offsets[13], object.showArchivedItems);
  writer.writeBool(offsets[14], object.showDeletedItems);
  writer.writeBool(offsets[15], object.soundEnabled);
  writer.writeBool(offsets[16], object.syncEnabled);
  writer.writeLong(offsets[17], object.syncIntervalMinutes);
  writer.writeBool(offsets[18], object.syncOnWifiOnly);
  writer.writeString(offsets[19], object.theme.name);
  writer.writeDateTime(offsets[20], object.updatedAt);
  writer.writeBool(offsets[21], object.vibrationEnabled);
}

AppSettings _appSettingsDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AppSettings();
  object.accentColor = reader.readStringOrNull(offsets[0]);
  object.autoSave = reader.readBool(offsets[1]);
  object.autoSaveIntervalSeconds = reader.readLong(offsets[2]);
  object.confirmBeforeDelete = reader.readBool(offsets[3]);
  object.defaultView = _AppSettingsdefaultViewValueEnumMap[
          reader.readStringOrNull(offsets[4])] ??
      DefaultView.list;
  object.defaultWorkspaceId = reader.readLongOrNull(offsets[5]);
  object.fontScale = reader.readDouble(offsets[6]);
  object.hasCompletedOnboarding = reader.readBool(offsets[7]);
  object.id = id;
  object.itemTypeColorsJson = reader.readStringOrNull(offsets[8]);
  object.language =
      _AppSettingslanguageValueEnumMap[reader.readStringOrNull(offsets[9])] ??
          AppLanguage.greek;
  object.lastSyncAt = reader.readDateTimeOrNull(offsets[10]);
  object.notificationsEnabled = reader.readBool(offsets[11]);
  object.preferredFolderId = reader.readLongOrNull(offsets[12]);
  object.showArchivedItems = reader.readBool(offsets[13]);
  object.showDeletedItems = reader.readBool(offsets[14]);
  object.soundEnabled = reader.readBool(offsets[15]);
  object.syncEnabled = reader.readBool(offsets[16]);
  object.syncIntervalMinutes = reader.readLong(offsets[17]);
  object.syncOnWifiOnly = reader.readBool(offsets[18]);
  object.theme =
      _AppSettingsthemeValueEnumMap[reader.readStringOrNull(offsets[19])] ??
          AppTheme.system;
  object.updatedAt = reader.readDateTime(offsets[20]);
  object.vibrationEnabled = reader.readBool(offsets[21]);
  return object;
}

P _appSettingsDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (_AppSettingsdefaultViewValueEnumMap[
              reader.readStringOrNull(offset)] ??
          DefaultView.list) as P;
    case 5:
      return (reader.readLongOrNull(offset)) as P;
    case 6:
      return (reader.readDouble(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (_AppSettingslanguageValueEnumMap[
              reader.readStringOrNull(offset)] ??
          AppLanguage.greek) as P;
    case 10:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 11:
      return (reader.readBool(offset)) as P;
    case 12:
      return (reader.readLongOrNull(offset)) as P;
    case 13:
      return (reader.readBool(offset)) as P;
    case 14:
      return (reader.readBool(offset)) as P;
    case 15:
      return (reader.readBool(offset)) as P;
    case 16:
      return (reader.readBool(offset)) as P;
    case 17:
      return (reader.readLong(offset)) as P;
    case 18:
      return (reader.readBool(offset)) as P;
    case 19:
      return (_AppSettingsthemeValueEnumMap[reader.readStringOrNull(offset)] ??
          AppTheme.system) as P;
    case 20:
      return (reader.readDateTime(offset)) as P;
    case 21:
      return (reader.readBool(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _AppSettingsdefaultViewEnumValueMap = {
  r'list': r'list',
  r'grid': r'grid',
  r'kanban': r'kanban',
  r'calendar': r'calendar',
};
const _AppSettingsdefaultViewValueEnumMap = {
  r'list': DefaultView.list,
  r'grid': DefaultView.grid,
  r'kanban': DefaultView.kanban,
  r'calendar': DefaultView.calendar,
};
const _AppSettingslanguageEnumValueMap = {
  r'greek': r'greek',
  r'english': r'english',
  r'auto': r'auto',
};
const _AppSettingslanguageValueEnumMap = {
  r'greek': AppLanguage.greek,
  r'english': AppLanguage.english,
  r'auto': AppLanguage.auto,
};
const _AppSettingsthemeEnumValueMap = {
  r'system': r'system',
  r'light': r'light',
  r'dark': r'dark',
};
const _AppSettingsthemeValueEnumMap = {
  r'system': AppTheme.system,
  r'light': AppTheme.light,
  r'dark': AppTheme.dark,
};

Id _appSettingsGetId(AppSettings object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _appSettingsGetLinks(AppSettings object) {
  return [];
}

void _appSettingsAttach(
    IsarCollection<dynamic> col, Id id, AppSettings object) {
  object.id = id;
}

extension AppSettingsQueryWhereSort
    on QueryBuilder<AppSettings, AppSettings, QWhere> {
  QueryBuilder<AppSettings, AppSettings, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AppSettingsQueryWhere
    on QueryBuilder<AppSettings, AppSettings, QWhereClause> {
  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension AppSettingsQueryFilter
    on QueryBuilder<AppSettings, AppSettings, QFilterCondition> {
  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      accentColorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'accentColor',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      accentColorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'accentColor',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      accentColorEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'accentColor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      accentColorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'accentColor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      accentColorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'accentColor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      accentColorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'accentColor',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      accentColorStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'accentColor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      accentColorEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'accentColor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      accentColorContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'accentColor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      accentColorMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'accentColor',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      accentColorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'accentColor',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      accentColorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'accentColor',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> autoSaveEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'autoSave',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      autoSaveIntervalSecondsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'autoSaveIntervalSeconds',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      autoSaveIntervalSecondsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'autoSaveIntervalSeconds',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      autoSaveIntervalSecondsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'autoSaveIntervalSeconds',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      autoSaveIntervalSecondsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'autoSaveIntervalSeconds',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      confirmBeforeDeleteEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'confirmBeforeDelete',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      defaultViewEqualTo(
    DefaultView value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'defaultView',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      defaultViewGreaterThan(
    DefaultView value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'defaultView',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      defaultViewLessThan(
    DefaultView value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'defaultView',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      defaultViewBetween(
    DefaultView lower,
    DefaultView upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'defaultView',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      defaultViewStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'defaultView',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      defaultViewEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'defaultView',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      defaultViewContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'defaultView',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      defaultViewMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'defaultView',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      defaultViewIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'defaultView',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      defaultViewIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'defaultView',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      defaultWorkspaceIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'defaultWorkspaceId',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      defaultWorkspaceIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'defaultWorkspaceId',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      defaultWorkspaceIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'defaultWorkspaceId',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      defaultWorkspaceIdGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'defaultWorkspaceId',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      defaultWorkspaceIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'defaultWorkspaceId',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      defaultWorkspaceIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'defaultWorkspaceId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      fontScaleEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fontScale',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      fontScaleGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fontScale',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      fontScaleLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fontScale',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      fontScaleBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fontScale',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      hasCompletedOnboardingEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hasCompletedOnboarding',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      itemTypeColorsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'itemTypeColorsJson',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      itemTypeColorsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'itemTypeColorsJson',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      itemTypeColorsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'itemTypeColorsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      itemTypeColorsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'itemTypeColorsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      itemTypeColorsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'itemTypeColorsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      itemTypeColorsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'itemTypeColorsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      itemTypeColorsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'itemTypeColorsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      itemTypeColorsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'itemTypeColorsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      itemTypeColorsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'itemTypeColorsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      itemTypeColorsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'itemTypeColorsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      itemTypeColorsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'itemTypeColorsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      itemTypeColorsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'itemTypeColorsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> languageEqualTo(
    AppLanguage value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'language',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      languageGreaterThan(
    AppLanguage value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'language',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      languageLessThan(
    AppLanguage value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'language',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> languageBetween(
    AppLanguage lower,
    AppLanguage upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'language',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      languageStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'language',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      languageEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'language',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      languageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'language',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> languageMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'language',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      languageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'language',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      languageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'language',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      lastSyncAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastSyncAt',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      lastSyncAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastSyncAt',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      lastSyncAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastSyncAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      lastSyncAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastSyncAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      lastSyncAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastSyncAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      lastSyncAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastSyncAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      notificationsEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notificationsEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      preferredFolderIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'preferredFolderId',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      preferredFolderIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'preferredFolderId',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      preferredFolderIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'preferredFolderId',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      preferredFolderIdGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'preferredFolderId',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      preferredFolderIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'preferredFolderId',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      preferredFolderIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'preferredFolderId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      showArchivedItemsEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'showArchivedItems',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      showDeletedItemsEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'showDeletedItems',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      soundEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'soundEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      syncEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      syncIntervalMinutesEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncIntervalMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      syncIntervalMinutesGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'syncIntervalMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      syncIntervalMinutesLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'syncIntervalMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      syncIntervalMinutesBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'syncIntervalMinutes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      syncOnWifiOnlyEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncOnWifiOnly',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> themeEqualTo(
    AppTheme value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'theme',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      themeGreaterThan(
    AppTheme value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'theme',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> themeLessThan(
    AppTheme value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'theme',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> themeBetween(
    AppTheme lower,
    AppTheme upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'theme',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> themeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'theme',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> themeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'theme',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> themeContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'theme',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> themeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'theme',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> themeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'theme',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      themeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'theme',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      vibrationEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'vibrationEnabled',
        value: value,
      ));
    });
  }
}

extension AppSettingsQueryObject
    on QueryBuilder<AppSettings, AppSettings, QFilterCondition> {}

extension AppSettingsQueryLinks
    on QueryBuilder<AppSettings, AppSettings, QFilterCondition> {}

extension AppSettingsQuerySortBy
    on QueryBuilder<AppSettings, AppSettings, QSortBy> {
  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByAccentColor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accentColor', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByAccentColorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accentColor', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByAutoSave() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoSave', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByAutoSaveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoSave', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByAutoSaveIntervalSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoSaveIntervalSeconds', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByAutoSaveIntervalSecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoSaveIntervalSeconds', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByConfirmBeforeDelete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmBeforeDelete', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByConfirmBeforeDeleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmBeforeDelete', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByDefaultView() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultView', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByDefaultViewDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultView', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByDefaultWorkspaceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultWorkspaceId', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByDefaultWorkspaceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultWorkspaceId', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByFontScale() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontScale', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByFontScaleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontScale', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByHasCompletedOnboarding() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasCompletedOnboarding', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByHasCompletedOnboardingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasCompletedOnboarding', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByItemTypeColorsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemTypeColorsJson', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByItemTypeColorsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemTypeColorsJson', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByLanguage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'language', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByLanguageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'language', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByLastSyncAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncAt', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByLastSyncAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncAt', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByNotificationsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notificationsEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByNotificationsEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notificationsEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByPreferredFolderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferredFolderId', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByPreferredFolderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferredFolderId', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByShowArchivedItems() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showArchivedItems', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByShowArchivedItemsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showArchivedItems', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByShowDeletedItems() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showDeletedItems', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByShowDeletedItemsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showDeletedItems', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortBySoundEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'soundEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortBySoundEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'soundEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortBySyncEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortBySyncEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortBySyncIntervalMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncIntervalMinutes', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortBySyncIntervalMinutesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncIntervalMinutes', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortBySyncOnWifiOnly() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncOnWifiOnly', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortBySyncOnWifiOnlyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncOnWifiOnly', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByTheme() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'theme', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByThemeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'theme', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByVibrationEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vibrationEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByVibrationEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vibrationEnabled', Sort.desc);
    });
  }
}

extension AppSettingsQuerySortThenBy
    on QueryBuilder<AppSettings, AppSettings, QSortThenBy> {
  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByAccentColor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accentColor', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByAccentColorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accentColor', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByAutoSave() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoSave', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByAutoSaveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoSave', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByAutoSaveIntervalSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoSaveIntervalSeconds', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByAutoSaveIntervalSecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoSaveIntervalSeconds', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByConfirmBeforeDelete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmBeforeDelete', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByConfirmBeforeDeleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmBeforeDelete', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByDefaultView() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultView', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByDefaultViewDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultView', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByDefaultWorkspaceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultWorkspaceId', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByDefaultWorkspaceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultWorkspaceId', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByFontScale() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontScale', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByFontScaleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontScale', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByHasCompletedOnboarding() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasCompletedOnboarding', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByHasCompletedOnboardingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasCompletedOnboarding', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByItemTypeColorsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemTypeColorsJson', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByItemTypeColorsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemTypeColorsJson', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByLanguage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'language', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByLanguageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'language', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByLastSyncAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncAt', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByLastSyncAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncAt', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByNotificationsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notificationsEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByNotificationsEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notificationsEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByPreferredFolderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferredFolderId', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByPreferredFolderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferredFolderId', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByShowArchivedItems() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showArchivedItems', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByShowArchivedItemsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showArchivedItems', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByShowDeletedItems() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showDeletedItems', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByShowDeletedItemsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showDeletedItems', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenBySoundEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'soundEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenBySoundEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'soundEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenBySyncEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenBySyncEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenBySyncIntervalMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncIntervalMinutes', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenBySyncIntervalMinutesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncIntervalMinutes', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenBySyncOnWifiOnly() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncOnWifiOnly', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenBySyncOnWifiOnlyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncOnWifiOnly', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByTheme() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'theme', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByThemeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'theme', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByVibrationEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vibrationEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByVibrationEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vibrationEnabled', Sort.desc);
    });
  }
}

extension AppSettingsQueryWhereDistinct
    on QueryBuilder<AppSettings, AppSettings, QDistinct> {
  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctByAccentColor(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'accentColor', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctByAutoSave() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'autoSave');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
      distinctByAutoSaveIntervalSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'autoSaveIntervalSeconds');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
      distinctByConfirmBeforeDelete() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'confirmBeforeDelete');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctByDefaultView(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'defaultView', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
      distinctByDefaultWorkspaceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'defaultWorkspaceId');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctByFontScale() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fontScale');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
      distinctByHasCompletedOnboarding() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hasCompletedOnboarding');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
      distinctByItemTypeColorsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'itemTypeColorsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctByLanguage(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'language', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctByLastSyncAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSyncAt');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
      distinctByNotificationsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notificationsEnabled');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
      distinctByPreferredFolderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'preferredFolderId');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
      distinctByShowArchivedItems() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'showArchivedItems');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
      distinctByShowDeletedItems() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'showDeletedItems');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctBySoundEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'soundEnabled');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctBySyncEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncEnabled');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
      distinctBySyncIntervalMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncIntervalMinutes');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctBySyncOnWifiOnly() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncOnWifiOnly');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctByTheme(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'theme', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
      distinctByVibrationEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'vibrationEnabled');
    });
  }
}

extension AppSettingsQueryProperty
    on QueryBuilder<AppSettings, AppSettings, QQueryProperty> {
  QueryBuilder<AppSettings, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AppSettings, String?, QQueryOperations> accentColorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'accentColor');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations> autoSaveProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'autoSave');
    });
  }

  QueryBuilder<AppSettings, int, QQueryOperations>
      autoSaveIntervalSecondsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'autoSaveIntervalSeconds');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations>
      confirmBeforeDeleteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'confirmBeforeDelete');
    });
  }

  QueryBuilder<AppSettings, DefaultView, QQueryOperations>
      defaultViewProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'defaultView');
    });
  }

  QueryBuilder<AppSettings, int?, QQueryOperations>
      defaultWorkspaceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'defaultWorkspaceId');
    });
  }

  QueryBuilder<AppSettings, double, QQueryOperations> fontScaleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fontScale');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations>
      hasCompletedOnboardingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hasCompletedOnboarding');
    });
  }

  QueryBuilder<AppSettings, String?, QQueryOperations>
      itemTypeColorsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'itemTypeColorsJson');
    });
  }

  QueryBuilder<AppSettings, AppLanguage, QQueryOperations> languageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'language');
    });
  }

  QueryBuilder<AppSettings, DateTime?, QQueryOperations> lastSyncAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSyncAt');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations>
      notificationsEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notificationsEnabled');
    });
  }

  QueryBuilder<AppSettings, int?, QQueryOperations>
      preferredFolderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'preferredFolderId');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations>
      showArchivedItemsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'showArchivedItems');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations> showDeletedItemsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'showDeletedItems');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations> soundEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'soundEnabled');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations> syncEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncEnabled');
    });
  }

  QueryBuilder<AppSettings, int, QQueryOperations>
      syncIntervalMinutesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncIntervalMinutes');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations> syncOnWifiOnlyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncOnWifiOnly');
    });
  }

  QueryBuilder<AppSettings, AppTheme, QQueryOperations> themeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'theme');
    });
  }

  QueryBuilder<AppSettings, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations> vibrationEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'vibrationEnabled');
    });
  }
}
