// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'relation.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetRelationCollection on Isar {
  IsarCollection<Relation> get relations => this.collection();
}

const RelationSchema = CollectionSchema(
  name: r'Relation',
  id: 4898379945116015801,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'fromItemId': PropertySchema(
      id: 1,
      name: r'fromItemId',
      type: IsarType.long,
    ),
    r'note': PropertySchema(
      id: 2,
      name: r'note',
      type: IsarType.string,
    ),
    r'relationType': PropertySchema(
      id: 3,
      name: r'relationType',
      type: IsarType.string,
      enumMap: _RelationrelationTypeEnumValueMap,
    ),
    r'toItemId': PropertySchema(
      id: 4,
      name: r'toItemId',
      type: IsarType.long,
    )
  },
  estimateSize: _relationEstimateSize,
  serialize: _relationSerialize,
  deserialize: _relationDeserialize,
  deserializeProp: _relationDeserializeProp,
  idName: r'id',
  indexes: {
    r'fromItemId_toItemId': IndexSchema(
      id: -4633266647249255041,
      name: r'fromItemId_toItemId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'fromItemId',
          type: IndexType.value,
          caseSensitive: false,
        ),
        IndexPropertySchema(
          name: r'toItemId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'toItemId': IndexSchema(
      id: -4527491266796801780,
      name: r'toItemId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'toItemId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _relationGetId,
  getLinks: _relationGetLinks,
  attach: _relationAttach,
  version: '3.1.0+1',
);

int _relationEstimateSize(
  Relation object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.note;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.relationType.name.length * 3;
  return bytesCount;
}

void _relationSerialize(
  Relation object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeLong(offsets[1], object.fromItemId);
  writer.writeString(offsets[2], object.note);
  writer.writeString(offsets[3], object.relationType.name);
  writer.writeLong(offsets[4], object.toItemId);
}

Relation _relationDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Relation();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.fromItemId = reader.readLong(offsets[1]);
  object.id = id;
  object.note = reader.readStringOrNull(offsets[2]);
  object.relationType =
      _RelationrelationTypeValueEnumMap[reader.readStringOrNull(offsets[3])] ??
          RelationType.parent;
  object.toItemId = reader.readLong(offsets[4]);
  return object;
}

P _relationDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (_RelationrelationTypeValueEnumMap[
              reader.readStringOrNull(offset)] ??
          RelationType.parent) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _RelationrelationTypeEnumValueMap = {
  r'parent': r'parent',
  r'child': r'child',
  r'related': r'related',
  r'blocks': r'blocks',
  r'blockedBy': r'blockedBy',
  r'references': r'references',
  r'duplicate': r'duplicate',
  r'linkedTo': r'linkedTo',
};
const _RelationrelationTypeValueEnumMap = {
  r'parent': RelationType.parent,
  r'child': RelationType.child,
  r'related': RelationType.related,
  r'blocks': RelationType.blocks,
  r'blockedBy': RelationType.blockedBy,
  r'references': RelationType.references,
  r'duplicate': RelationType.duplicate,
  r'linkedTo': RelationType.linkedTo,
};

Id _relationGetId(Relation object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _relationGetLinks(Relation object) {
  return [];
}

void _relationAttach(IsarCollection<dynamic> col, Id id, Relation object) {
  object.id = id;
}

extension RelationQueryWhereSort on QueryBuilder<Relation, Relation, QWhere> {
  QueryBuilder<Relation, Relation, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhere> anyFromItemIdToItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'fromItemId_toItemId'),
      );
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhere> anyToItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'toItemId'),
      );
    });
  }
}

extension RelationQueryWhere on QueryBuilder<Relation, Relation, QWhereClause> {
  QueryBuilder<Relation, Relation, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Relation, Relation, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhereClause> idBetween(
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

  QueryBuilder<Relation, Relation, QAfterWhereClause>
      fromItemIdEqualToAnyToItemId(int fromItemId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'fromItemId_toItemId',
        value: [fromItemId],
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhereClause>
      fromItemIdNotEqualToAnyToItemId(int fromItemId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'fromItemId_toItemId',
              lower: [],
              upper: [fromItemId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'fromItemId_toItemId',
              lower: [fromItemId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'fromItemId_toItemId',
              lower: [fromItemId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'fromItemId_toItemId',
              lower: [],
              upper: [fromItemId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhereClause>
      fromItemIdGreaterThanAnyToItemId(
    int fromItemId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'fromItemId_toItemId',
        lower: [fromItemId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhereClause>
      fromItemIdLessThanAnyToItemId(
    int fromItemId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'fromItemId_toItemId',
        lower: [],
        upper: [fromItemId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhereClause>
      fromItemIdBetweenAnyToItemId(
    int lowerFromItemId,
    int upperFromItemId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'fromItemId_toItemId',
        lower: [lowerFromItemId],
        includeLower: includeLower,
        upper: [upperFromItemId],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhereClause> fromItemIdToItemIdEqualTo(
      int fromItemId, int toItemId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'fromItemId_toItemId',
        value: [fromItemId, toItemId],
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhereClause>
      fromItemIdEqualToToItemIdNotEqualTo(int fromItemId, int toItemId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'fromItemId_toItemId',
              lower: [fromItemId],
              upper: [fromItemId, toItemId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'fromItemId_toItemId',
              lower: [fromItemId, toItemId],
              includeLower: false,
              upper: [fromItemId],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'fromItemId_toItemId',
              lower: [fromItemId, toItemId],
              includeLower: false,
              upper: [fromItemId],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'fromItemId_toItemId',
              lower: [fromItemId],
              upper: [fromItemId, toItemId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhereClause>
      fromItemIdEqualToToItemIdGreaterThan(
    int fromItemId,
    int toItemId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'fromItemId_toItemId',
        lower: [fromItemId, toItemId],
        includeLower: include,
        upper: [fromItemId],
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhereClause>
      fromItemIdEqualToToItemIdLessThan(
    int fromItemId,
    int toItemId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'fromItemId_toItemId',
        lower: [fromItemId],
        upper: [fromItemId, toItemId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhereClause>
      fromItemIdEqualToToItemIdBetween(
    int fromItemId,
    int lowerToItemId,
    int upperToItemId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'fromItemId_toItemId',
        lower: [fromItemId, lowerToItemId],
        includeLower: includeLower,
        upper: [fromItemId, upperToItemId],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhereClause> toItemIdEqualTo(
      int toItemId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'toItemId',
        value: [toItemId],
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhereClause> toItemIdNotEqualTo(
      int toItemId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'toItemId',
              lower: [],
              upper: [toItemId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'toItemId',
              lower: [toItemId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'toItemId',
              lower: [toItemId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'toItemId',
              lower: [],
              upper: [toItemId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhereClause> toItemIdGreaterThan(
    int toItemId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'toItemId',
        lower: [toItemId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhereClause> toItemIdLessThan(
    int toItemId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'toItemId',
        lower: [],
        upper: [toItemId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterWhereClause> toItemIdBetween(
    int lowerToItemId,
    int upperToItemId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'toItemId',
        lower: [lowerToItemId],
        includeLower: includeLower,
        upper: [upperToItemId],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension RelationQueryFilter
    on QueryBuilder<Relation, Relation, QFilterCondition> {
  QueryBuilder<Relation, Relation, QAfterFilterCondition> createdAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> fromItemIdEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fromItemId',
        value: value,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> fromItemIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fromItemId',
        value: value,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> fromItemIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fromItemId',
        value: value,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> fromItemIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fromItemId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Relation, Relation, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Relation, Relation, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Relation, Relation, QAfterFilterCondition> noteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'note',
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> noteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'note',
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> noteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> noteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> noteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> noteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'note',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> noteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> noteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> noteContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> noteMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'note',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> noteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> noteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> relationTypeEqualTo(
    RelationType value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'relationType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition>
      relationTypeGreaterThan(
    RelationType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'relationType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> relationTypeLessThan(
    RelationType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'relationType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> relationTypeBetween(
    RelationType lower,
    RelationType upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'relationType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition>
      relationTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'relationType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> relationTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'relationType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> relationTypeContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'relationType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> relationTypeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'relationType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition>
      relationTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'relationType',
        value: '',
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition>
      relationTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'relationType',
        value: '',
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> toItemIdEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'toItemId',
        value: value,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> toItemIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'toItemId',
        value: value,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> toItemIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'toItemId',
        value: value,
      ));
    });
  }

  QueryBuilder<Relation, Relation, QAfterFilterCondition> toItemIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'toItemId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension RelationQueryObject
    on QueryBuilder<Relation, Relation, QFilterCondition> {}

extension RelationQueryLinks
    on QueryBuilder<Relation, Relation, QFilterCondition> {}

extension RelationQuerySortBy on QueryBuilder<Relation, Relation, QSortBy> {
  QueryBuilder<Relation, Relation, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> sortByFromItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromItemId', Sort.asc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> sortByFromItemIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromItemId', Sort.desc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> sortByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> sortByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> sortByRelationType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relationType', Sort.asc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> sortByRelationTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relationType', Sort.desc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> sortByToItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toItemId', Sort.asc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> sortByToItemIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toItemId', Sort.desc);
    });
  }
}

extension RelationQuerySortThenBy
    on QueryBuilder<Relation, Relation, QSortThenBy> {
  QueryBuilder<Relation, Relation, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> thenByFromItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromItemId', Sort.asc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> thenByFromItemIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromItemId', Sort.desc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> thenByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> thenByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> thenByRelationType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relationType', Sort.asc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> thenByRelationTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relationType', Sort.desc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> thenByToItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toItemId', Sort.asc);
    });
  }

  QueryBuilder<Relation, Relation, QAfterSortBy> thenByToItemIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toItemId', Sort.desc);
    });
  }
}

extension RelationQueryWhereDistinct
    on QueryBuilder<Relation, Relation, QDistinct> {
  QueryBuilder<Relation, Relation, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<Relation, Relation, QDistinct> distinctByFromItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fromItemId');
    });
  }

  QueryBuilder<Relation, Relation, QDistinct> distinctByNote(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'note', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Relation, Relation, QDistinct> distinctByRelationType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'relationType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Relation, Relation, QDistinct> distinctByToItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'toItemId');
    });
  }
}

extension RelationQueryProperty
    on QueryBuilder<Relation, Relation, QQueryProperty> {
  QueryBuilder<Relation, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Relation, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<Relation, int, QQueryOperations> fromItemIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fromItemId');
    });
  }

  QueryBuilder<Relation, String?, QQueryOperations> noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'note');
    });
  }

  QueryBuilder<Relation, RelationType, QQueryOperations>
      relationTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'relationType');
    });
  }

  QueryBuilder<Relation, int, QQueryOperations> toItemIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'toItemId');
    });
  }
}
