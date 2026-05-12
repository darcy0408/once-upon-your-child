// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hero_profile_local_io.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetHeroProfileLocalCollection on Isar {
  IsarCollection<HeroProfileLocal> get heroProfileLocals => this.collection();
}

const HeroProfileLocalSchema = CollectionSchema(
  name: r'HeroProfileLocal',
  id: -6042960139672722896,
  properties: {
    r'capeStyle': PropertySchema(
      id: 0,
      name: r'capeStyle',
      type: IsarType.string,
    ),
    r'characterId': PropertySchema(
      id: 1,
      name: r'characterId',
      type: IsarType.string,
    ),
    r'costumeColor': PropertySchema(
      id: 2,
      name: r'costumeColor',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 3,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'emblem': PropertySchema(
      id: 4,
      name: r'emblem',
      type: IsarType.string,
    ),
    r'heroName': PropertySchema(
      id: 5,
      name: r'heroName',
      type: IsarType.string,
    ),
    r'power': PropertySchema(
      id: 6,
      name: r'power',
      type: IsarType.string,
    ),
    r'recentProblems': PropertySchema(
      id: 7,
      name: r'recentProblems',
      type: IsarType.stringList,
    ),
    r'recentVillains': PropertySchema(
      id: 8,
      name: r'recentVillains',
      type: IsarType.stringList,
    ),
    r'updatedAt': PropertySchema(
      id: 9,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _heroProfileLocalEstimateSize,
  serialize: _heroProfileLocalSerialize,
  deserialize: _heroProfileLocalDeserialize,
  deserializeProp: _heroProfileLocalDeserializeProp,
  idName: r'id',
  indexes: {
    r'characterId': IndexSchema(
      id: 8442520835599207285,
      name: r'characterId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'characterId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _heroProfileLocalGetId,
  getLinks: _heroProfileLocalGetLinks,
  attach: _heroProfileLocalAttach,
  version: '3.1.0+1',
);

int _heroProfileLocalEstimateSize(
  HeroProfileLocal object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.capeStyle;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.characterId.length * 3;
  {
    final value = object.costumeColor;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.emblem;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.heroName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.power;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.recentProblems.length * 3;
  {
    for (var i = 0; i < object.recentProblems.length; i++) {
      final value = object.recentProblems[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.recentVillains.length * 3;
  {
    for (var i = 0; i < object.recentVillains.length; i++) {
      final value = object.recentVillains[i];
      bytesCount += value.length * 3;
    }
  }
  return bytesCount;
}

void _heroProfileLocalSerialize(
  HeroProfileLocal object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.capeStyle);
  writer.writeString(offsets[1], object.characterId);
  writer.writeString(offsets[2], object.costumeColor);
  writer.writeDateTime(offsets[3], object.createdAt);
  writer.writeString(offsets[4], object.emblem);
  writer.writeString(offsets[5], object.heroName);
  writer.writeString(offsets[6], object.power);
  writer.writeStringList(offsets[7], object.recentProblems);
  writer.writeStringList(offsets[8], object.recentVillains);
  writer.writeDateTime(offsets[9], object.updatedAt);
}

HeroProfileLocal _heroProfileLocalDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = HeroProfileLocal();
  object.capeStyle = reader.readStringOrNull(offsets[0]);
  object.characterId = reader.readString(offsets[1]);
  object.costumeColor = reader.readStringOrNull(offsets[2]);
  object.createdAt = reader.readDateTime(offsets[3]);
  object.emblem = reader.readStringOrNull(offsets[4]);
  object.heroName = reader.readStringOrNull(offsets[5]);
  object.id = id;
  object.power = reader.readStringOrNull(offsets[6]);
  object.recentProblems = reader.readStringList(offsets[7]) ?? [];
  object.recentVillains = reader.readStringList(offsets[8]) ?? [];
  object.updatedAt = reader.readDateTime(offsets[9]);
  return object;
}

P _heroProfileLocalDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readStringList(offset) ?? []) as P;
    case 8:
      return (reader.readStringList(offset) ?? []) as P;
    case 9:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _heroProfileLocalGetId(HeroProfileLocal object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _heroProfileLocalGetLinks(HeroProfileLocal object) {
  return [];
}

void _heroProfileLocalAttach(
    IsarCollection<dynamic> col, Id id, HeroProfileLocal object) {
  object.id = id;
}

extension HeroProfileLocalByIndex on IsarCollection<HeroProfileLocal> {
  Future<HeroProfileLocal?> getByCharacterId(String characterId) {
    return getByIndex(r'characterId', [characterId]);
  }

  HeroProfileLocal? getByCharacterIdSync(String characterId) {
    return getByIndexSync(r'characterId', [characterId]);
  }

  Future<bool> deleteByCharacterId(String characterId) {
    return deleteByIndex(r'characterId', [characterId]);
  }

  bool deleteByCharacterIdSync(String characterId) {
    return deleteByIndexSync(r'characterId', [characterId]);
  }

  Future<List<HeroProfileLocal?>> getAllByCharacterId(
      List<String> characterIdValues) {
    final values = characterIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'characterId', values);
  }

  List<HeroProfileLocal?> getAllByCharacterIdSync(
      List<String> characterIdValues) {
    final values = characterIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'characterId', values);
  }

  Future<int> deleteAllByCharacterId(List<String> characterIdValues) {
    final values = characterIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'characterId', values);
  }

  int deleteAllByCharacterIdSync(List<String> characterIdValues) {
    final values = characterIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'characterId', values);
  }

  Future<Id> putByCharacterId(HeroProfileLocal object) {
    return putByIndex(r'characterId', object);
  }

  Id putByCharacterIdSync(HeroProfileLocal object, {bool saveLinks = true}) {
    return putByIndexSync(r'characterId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCharacterId(List<HeroProfileLocal> objects) {
    return putAllByIndex(r'characterId', objects);
  }

  List<Id> putAllByCharacterIdSync(List<HeroProfileLocal> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'characterId', objects, saveLinks: saveLinks);
  }
}

extension HeroProfileLocalQueryWhereSort
    on QueryBuilder<HeroProfileLocal, HeroProfileLocal, QWhere> {
  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension HeroProfileLocalQueryWhere
    on QueryBuilder<HeroProfileLocal, HeroProfileLocal, QWhereClause> {
  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterWhereClause>
      idNotEqualTo(Id id) {
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

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterWhereClause> idBetween(
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

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterWhereClause>
      characterIdEqualTo(String characterId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'characterId',
        value: [characterId],
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterWhereClause>
      characterIdNotEqualTo(String characterId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'characterId',
              lower: [],
              upper: [characterId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'characterId',
              lower: [characterId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'characterId',
              lower: [characterId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'characterId',
              lower: [],
              upper: [characterId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension HeroProfileLocalQueryFilter
    on QueryBuilder<HeroProfileLocal, HeroProfileLocal, QFilterCondition> {
  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      capeStyleIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'capeStyle',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      capeStyleIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'capeStyle',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      capeStyleEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'capeStyle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      capeStyleGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'capeStyle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      capeStyleLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'capeStyle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      capeStyleBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'capeStyle',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      capeStyleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'capeStyle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      capeStyleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'capeStyle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      capeStyleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'capeStyle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      capeStyleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'capeStyle',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      capeStyleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'capeStyle',
        value: '',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      capeStyleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'capeStyle',
        value: '',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      characterIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'characterId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      characterIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'characterId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      characterIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'characterId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      characterIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'characterId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      characterIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'characterId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      characterIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'characterId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      characterIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'characterId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      characterIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'characterId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      characterIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'characterId',
        value: '',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      characterIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'characterId',
        value: '',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      costumeColorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'costumeColor',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      costumeColorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'costumeColor',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      costumeColorEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'costumeColor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      costumeColorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'costumeColor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      costumeColorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'costumeColor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      costumeColorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'costumeColor',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      costumeColorStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'costumeColor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      costumeColorEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'costumeColor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      costumeColorContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'costumeColor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      costumeColorMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'costumeColor',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      costumeColorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'costumeColor',
        value: '',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      costumeColorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'costumeColor',
        value: '',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      createdAtGreaterThan(
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

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      createdAtLessThan(
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

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      createdAtBetween(
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

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      emblemIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'emblem',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      emblemIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'emblem',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      emblemEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'emblem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      emblemGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'emblem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      emblemLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'emblem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      emblemBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'emblem',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      emblemStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'emblem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      emblemEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'emblem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      emblemContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'emblem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      emblemMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'emblem',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      emblemIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'emblem',
        value: '',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      emblemIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'emblem',
        value: '',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      heroNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'heroName',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      heroNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'heroName',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      heroNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'heroName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      heroNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'heroName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      heroNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'heroName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      heroNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'heroName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      heroNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'heroName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      heroNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'heroName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      heroNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'heroName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      heroNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'heroName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      heroNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'heroName',
        value: '',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      heroNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'heroName',
        value: '',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      idGreaterThan(
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

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      idLessThan(
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

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      idBetween(
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

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      powerIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'power',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      powerIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'power',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      powerEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'power',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      powerGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'power',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      powerLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'power',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      powerBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'power',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      powerStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'power',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      powerEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'power',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      powerContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'power',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      powerMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'power',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      powerIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'power',
        value: '',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      powerIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'power',
        value: '',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentProblemsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recentProblems',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentProblemsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'recentProblems',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentProblemsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'recentProblems',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentProblemsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'recentProblems',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentProblemsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'recentProblems',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentProblemsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'recentProblems',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentProblemsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'recentProblems',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentProblemsElementMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'recentProblems',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentProblemsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recentProblems',
        value: '',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentProblemsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'recentProblems',
        value: '',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentProblemsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'recentProblems',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentProblemsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'recentProblems',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentProblemsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'recentProblems',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentProblemsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'recentProblems',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentProblemsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'recentProblems',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentProblemsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'recentProblems',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentVillainsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recentVillains',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentVillainsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'recentVillains',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentVillainsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'recentVillains',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentVillainsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'recentVillains',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentVillainsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'recentVillains',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentVillainsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'recentVillains',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentVillainsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'recentVillains',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentVillainsElementMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'recentVillains',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentVillainsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recentVillains',
        value: '',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentVillainsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'recentVillains',
        value: '',
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentVillainsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'recentVillains',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentVillainsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'recentVillains',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentVillainsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'recentVillains',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentVillainsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'recentVillains',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentVillainsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'recentVillains',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      recentVillainsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'recentVillains',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
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

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
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

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterFilterCondition>
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
}

extension HeroProfileLocalQueryObject
    on QueryBuilder<HeroProfileLocal, HeroProfileLocal, QFilterCondition> {}

extension HeroProfileLocalQueryLinks
    on QueryBuilder<HeroProfileLocal, HeroProfileLocal, QFilterCondition> {}

extension HeroProfileLocalQuerySortBy
    on QueryBuilder<HeroProfileLocal, HeroProfileLocal, QSortBy> {
  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      sortByCapeStyle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'capeStyle', Sort.asc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      sortByCapeStyleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'capeStyle', Sort.desc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      sortByCharacterId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterId', Sort.asc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      sortByCharacterIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterId', Sort.desc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      sortByCostumeColor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'costumeColor', Sort.asc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      sortByCostumeColorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'costumeColor', Sort.desc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      sortByEmblem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'emblem', Sort.asc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      sortByEmblemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'emblem', Sort.desc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      sortByHeroName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heroName', Sort.asc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      sortByHeroNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heroName', Sort.desc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy> sortByPower() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'power', Sort.asc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      sortByPowerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'power', Sort.desc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension HeroProfileLocalQuerySortThenBy
    on QueryBuilder<HeroProfileLocal, HeroProfileLocal, QSortThenBy> {
  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      thenByCapeStyle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'capeStyle', Sort.asc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      thenByCapeStyleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'capeStyle', Sort.desc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      thenByCharacterId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterId', Sort.asc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      thenByCharacterIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterId', Sort.desc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      thenByCostumeColor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'costumeColor', Sort.asc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      thenByCostumeColorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'costumeColor', Sort.desc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      thenByEmblem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'emblem', Sort.asc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      thenByEmblemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'emblem', Sort.desc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      thenByHeroName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heroName', Sort.asc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      thenByHeroNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heroName', Sort.desc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy> thenByPower() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'power', Sort.asc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      thenByPowerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'power', Sort.desc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension HeroProfileLocalQueryWhereDistinct
    on QueryBuilder<HeroProfileLocal, HeroProfileLocal, QDistinct> {
  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QDistinct>
      distinctByCapeStyle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'capeStyle', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QDistinct>
      distinctByCharacterId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'characterId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QDistinct>
      distinctByCostumeColor({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'costumeColor', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QDistinct> distinctByEmblem(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'emblem', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QDistinct>
      distinctByHeroName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'heroName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QDistinct> distinctByPower(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'power', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QDistinct>
      distinctByRecentProblems() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recentProblems');
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QDistinct>
      distinctByRecentVillains() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recentVillains');
    });
  }

  QueryBuilder<HeroProfileLocal, HeroProfileLocal, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension HeroProfileLocalQueryProperty
    on QueryBuilder<HeroProfileLocal, HeroProfileLocal, QQueryProperty> {
  QueryBuilder<HeroProfileLocal, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<HeroProfileLocal, String?, QQueryOperations>
      capeStyleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'capeStyle');
    });
  }

  QueryBuilder<HeroProfileLocal, String, QQueryOperations>
      characterIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'characterId');
    });
  }

  QueryBuilder<HeroProfileLocal, String?, QQueryOperations>
      costumeColorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'costumeColor');
    });
  }

  QueryBuilder<HeroProfileLocal, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<HeroProfileLocal, String?, QQueryOperations> emblemProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'emblem');
    });
  }

  QueryBuilder<HeroProfileLocal, String?, QQueryOperations> heroNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'heroName');
    });
  }

  QueryBuilder<HeroProfileLocal, String?, QQueryOperations> powerProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'power');
    });
  }

  QueryBuilder<HeroProfileLocal, List<String>, QQueryOperations>
      recentProblemsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recentProblems');
    });
  }

  QueryBuilder<HeroProfileLocal, List<String>, QQueryOperations>
      recentVillainsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recentVillains');
    });
  }

  QueryBuilder<HeroProfileLocal, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
