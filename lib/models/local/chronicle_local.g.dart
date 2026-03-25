// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chronicle_local.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChronicleLocalCollection on Isar {
  IsarCollection<ChronicleLocal> get chronicleLocals => this.collection();
}

const ChronicleLocalSchema = CollectionSchema(
  name: r'ChronicleLocal',
  id: 3397590408497397061,
  properties: {
    r'arcSummariesJson': PropertySchema(
      id: 0,
      name: r'arcSummariesJson',
      type: IsarType.string,
    ),
    r'chapterCount': PropertySchema(
      id: 1,
      name: r'chapterCount',
      type: IsarType.long,
    ),
    r'characterAge': PropertySchema(
      id: 2,
      name: r'characterAge',
      type: IsarType.long,
    ),
    r'characterId': PropertySchema(
      id: 3,
      name: r'characterId',
      type: IsarType.string,
    ),
    r'characterName': PropertySchema(
      id: 4,
      name: r'characterName',
      type: IsarType.string,
    ),
    r'characterStateJson': PropertySchema(
      id: 5,
      name: r'characterStateJson',
      type: IsarType.string,
    ),
    r'chronicleId': PropertySchema(
      id: 6,
      name: r'chronicleId',
      type: IsarType.string,
    ),
    r'coverImageBase64': PropertySchema(
      id: 7,
      name: r'coverImageBase64',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 8,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'genre': PropertySchema(
      id: 9,
      name: r'genre',
      type: IsarType.string,
    ),
    r'isActive': PropertySchema(
      id: 10,
      name: r'isActive',
      type: IsarType.bool,
    ),
    r'lastChapterEnding': PropertySchema(
      id: 11,
      name: r'lastChapterEnding',
      type: IsarType.string,
    ),
    r'lastChoiceMade': PropertySchema(
      id: 12,
      name: r'lastChoiceMade',
      type: IsarType.string,
    ),
    r'lastPlayedAt': PropertySchema(
      id: 13,
      name: r'lastPlayedAt',
      type: IsarType.dateTime,
    ),
    r'recentMemoriesJson': PropertySchema(
      id: 14,
      name: r'recentMemoriesJson',
      type: IsarType.string,
    ),
    r'title': PropertySchema(
      id: 15,
      name: r'title',
      type: IsarType.string,
    ),
    r'unresolvedThreadsJson': PropertySchema(
      id: 16,
      name: r'unresolvedThreadsJson',
      type: IsarType.string,
    ),
    r'worldFactsJson': PropertySchema(
      id: 17,
      name: r'worldFactsJson',
      type: IsarType.string,
    )
  },
  estimateSize: _chronicleLocalEstimateSize,
  serialize: _chronicleLocalSerialize,
  deserialize: _chronicleLocalDeserialize,
  deserializeProp: _chronicleLocalDeserializeProp,
  idName: r'id',
  indexes: {
    r'chronicleId': IndexSchema(
      id: -2677070409302973780,
      name: r'chronicleId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'chronicleId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'characterId': IndexSchema(
      id: 8442520835599207285,
      name: r'characterId',
      unique: false,
      replace: false,
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
  getId: _chronicleLocalGetId,
  getLinks: _chronicleLocalGetLinks,
  attach: _chronicleLocalAttach,
  version: '3.1.0+1',
);

int _chronicleLocalEstimateSize(
  ChronicleLocal object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.arcSummariesJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.characterId.length * 3;
  bytesCount += 3 + object.characterName.length * 3;
  {
    final value = object.characterStateJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.chronicleId.length * 3;
  {
    final value = object.coverImageBase64;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.genre.length * 3;
  {
    final value = object.lastChapterEnding;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.lastChoiceMade;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.recentMemoriesJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  {
    final value = object.unresolvedThreadsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.worldFactsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _chronicleLocalSerialize(
  ChronicleLocal object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.arcSummariesJson);
  writer.writeLong(offsets[1], object.chapterCount);
  writer.writeLong(offsets[2], object.characterAge);
  writer.writeString(offsets[3], object.characterId);
  writer.writeString(offsets[4], object.characterName);
  writer.writeString(offsets[5], object.characterStateJson);
  writer.writeString(offsets[6], object.chronicleId);
  writer.writeString(offsets[7], object.coverImageBase64);
  writer.writeDateTime(offsets[8], object.createdAt);
  writer.writeString(offsets[9], object.genre);
  writer.writeBool(offsets[10], object.isActive);
  writer.writeString(offsets[11], object.lastChapterEnding);
  writer.writeString(offsets[12], object.lastChoiceMade);
  writer.writeDateTime(offsets[13], object.lastPlayedAt);
  writer.writeString(offsets[14], object.recentMemoriesJson);
  writer.writeString(offsets[15], object.title);
  writer.writeString(offsets[16], object.unresolvedThreadsJson);
  writer.writeString(offsets[17], object.worldFactsJson);
}

ChronicleLocal _chronicleLocalDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChronicleLocal();
  object.arcSummariesJson = reader.readStringOrNull(offsets[0]);
  object.chapterCount = reader.readLong(offsets[1]);
  object.characterAge = reader.readLong(offsets[2]);
  object.characterId = reader.readString(offsets[3]);
  object.characterName = reader.readString(offsets[4]);
  object.characterStateJson = reader.readStringOrNull(offsets[5]);
  object.chronicleId = reader.readString(offsets[6]);
  object.coverImageBase64 = reader.readStringOrNull(offsets[7]);
  object.createdAt = reader.readDateTime(offsets[8]);
  object.genre = reader.readString(offsets[9]);
  object.id = id;
  object.isActive = reader.readBool(offsets[10]);
  object.lastChapterEnding = reader.readStringOrNull(offsets[11]);
  object.lastChoiceMade = reader.readStringOrNull(offsets[12]);
  object.lastPlayedAt = reader.readDateTime(offsets[13]);
  object.recentMemoriesJson = reader.readStringOrNull(offsets[14]);
  object.title = reader.readString(offsets[15]);
  object.unresolvedThreadsJson = reader.readStringOrNull(offsets[16]);
  object.worldFactsJson = reader.readStringOrNull(offsets[17]);
  return object;
}

P _chronicleLocalDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readDateTime(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readBool(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readDateTime(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    case 16:
      return (reader.readStringOrNull(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chronicleLocalGetId(ChronicleLocal object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chronicleLocalGetLinks(ChronicleLocal object) {
  return [];
}

void _chronicleLocalAttach(
    IsarCollection<dynamic> col, Id id, ChronicleLocal object) {
  object.id = id;
}

extension ChronicleLocalQueryWhereSort
    on QueryBuilder<ChronicleLocal, ChronicleLocal, QWhere> {
  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ChronicleLocalQueryWhere
    on QueryBuilder<ChronicleLocal, ChronicleLocal, QWhereClause> {
  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterWhereClause> idBetween(
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

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterWhereClause>
      chronicleIdEqualTo(String chronicleId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'chronicleId',
        value: [chronicleId],
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterWhereClause>
      chronicleIdNotEqualTo(String chronicleId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chronicleId',
              lower: [],
              upper: [chronicleId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chronicleId',
              lower: [chronicleId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chronicleId',
              lower: [chronicleId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chronicleId',
              lower: [],
              upper: [chronicleId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterWhereClause>
      characterIdEqualTo(String characterId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'characterId',
        value: [characterId],
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterWhereClause>
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

extension ChronicleLocalQueryFilter
    on QueryBuilder<ChronicleLocal, ChronicleLocal, QFilterCondition> {
  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      arcSummariesJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'arcSummariesJson',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      arcSummariesJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'arcSummariesJson',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      arcSummariesJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'arcSummariesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      arcSummariesJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'arcSummariesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      arcSummariesJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'arcSummariesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      arcSummariesJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'arcSummariesJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      arcSummariesJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'arcSummariesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      arcSummariesJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'arcSummariesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      arcSummariesJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'arcSummariesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      arcSummariesJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'arcSummariesJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      arcSummariesJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'arcSummariesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      arcSummariesJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'arcSummariesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      chapterCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chapterCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      chapterCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chapterCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      chapterCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chapterCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      chapterCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chapterCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterAgeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'characterAge',
        value: value,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterAgeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'characterAge',
        value: value,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterAgeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'characterAge',
        value: value,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterAgeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'characterAge',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
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

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
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

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
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

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
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

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
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

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
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

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'characterId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'characterId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'characterId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'characterId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'characterName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'characterName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'characterName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'characterName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'characterName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'characterName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'characterName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'characterName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'characterName',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'characterName',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterStateJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'characterStateJson',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterStateJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'characterStateJson',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterStateJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'characterStateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterStateJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'characterStateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterStateJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'characterStateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterStateJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'characterStateJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterStateJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'characterStateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterStateJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'characterStateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterStateJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'characterStateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterStateJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'characterStateJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterStateJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'characterStateJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      characterStateJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'characterStateJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      chronicleIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chronicleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      chronicleIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chronicleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      chronicleIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chronicleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      chronicleIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chronicleId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      chronicleIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'chronicleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      chronicleIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'chronicleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      chronicleIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'chronicleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      chronicleIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'chronicleId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      chronicleIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chronicleId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      chronicleIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'chronicleId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      coverImageBase64IsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'coverImageBase64',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      coverImageBase64IsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'coverImageBase64',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      coverImageBase64EqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'coverImageBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      coverImageBase64GreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'coverImageBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      coverImageBase64LessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'coverImageBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      coverImageBase64Between(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'coverImageBase64',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      coverImageBase64StartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'coverImageBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      coverImageBase64EndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'coverImageBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      coverImageBase64Contains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'coverImageBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      coverImageBase64Matches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'coverImageBase64',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      coverImageBase64IsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'coverImageBase64',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      coverImageBase64IsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'coverImageBase64',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
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

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
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

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
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

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      genreEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'genre',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      genreGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'genre',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      genreLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'genre',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      genreBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'genre',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      genreStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'genre',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      genreEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'genre',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      genreContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'genre',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      genreMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'genre',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      genreIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'genre',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      genreIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'genre',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
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

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
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

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition> idBetween(
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

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      isActiveEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isActive',
        value: value,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChapterEndingIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastChapterEnding',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChapterEndingIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastChapterEnding',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChapterEndingEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastChapterEnding',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChapterEndingGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastChapterEnding',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChapterEndingLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastChapterEnding',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChapterEndingBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastChapterEnding',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChapterEndingStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastChapterEnding',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChapterEndingEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastChapterEnding',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChapterEndingContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastChapterEnding',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChapterEndingMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastChapterEnding',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChapterEndingIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastChapterEnding',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChapterEndingIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastChapterEnding',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChoiceMadeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastChoiceMade',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChoiceMadeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastChoiceMade',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChoiceMadeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastChoiceMade',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChoiceMadeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastChoiceMade',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChoiceMadeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastChoiceMade',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChoiceMadeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastChoiceMade',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChoiceMadeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastChoiceMade',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChoiceMadeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastChoiceMade',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChoiceMadeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastChoiceMade',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChoiceMadeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastChoiceMade',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChoiceMadeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastChoiceMade',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastChoiceMadeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastChoiceMade',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastPlayedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastPlayedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastPlayedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastPlayedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastPlayedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastPlayedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      lastPlayedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastPlayedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      recentMemoriesJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'recentMemoriesJson',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      recentMemoriesJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'recentMemoriesJson',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      recentMemoriesJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recentMemoriesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      recentMemoriesJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'recentMemoriesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      recentMemoriesJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'recentMemoriesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      recentMemoriesJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'recentMemoriesJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      recentMemoriesJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'recentMemoriesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      recentMemoriesJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'recentMemoriesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      recentMemoriesJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'recentMemoriesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      recentMemoriesJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'recentMemoriesJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      recentMemoriesJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recentMemoriesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      recentMemoriesJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'recentMemoriesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      unresolvedThreadsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'unresolvedThreadsJson',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      unresolvedThreadsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'unresolvedThreadsJson',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      unresolvedThreadsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'unresolvedThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      unresolvedThreadsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'unresolvedThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      unresolvedThreadsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'unresolvedThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      unresolvedThreadsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'unresolvedThreadsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      unresolvedThreadsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'unresolvedThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      unresolvedThreadsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'unresolvedThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      unresolvedThreadsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'unresolvedThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      unresolvedThreadsJsonMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'unresolvedThreadsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      unresolvedThreadsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'unresolvedThreadsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      unresolvedThreadsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'unresolvedThreadsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      worldFactsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'worldFactsJson',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      worldFactsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'worldFactsJson',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      worldFactsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'worldFactsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      worldFactsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'worldFactsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      worldFactsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'worldFactsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      worldFactsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'worldFactsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      worldFactsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'worldFactsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      worldFactsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'worldFactsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      worldFactsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'worldFactsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      worldFactsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'worldFactsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      worldFactsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'worldFactsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterFilterCondition>
      worldFactsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'worldFactsJson',
        value: '',
      ));
    });
  }
}

extension ChronicleLocalQueryObject
    on QueryBuilder<ChronicleLocal, ChronicleLocal, QFilterCondition> {}

extension ChronicleLocalQueryLinks
    on QueryBuilder<ChronicleLocal, ChronicleLocal, QFilterCondition> {}

extension ChronicleLocalQuerySortBy
    on QueryBuilder<ChronicleLocal, ChronicleLocal, QSortBy> {
  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByArcSummariesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'arcSummariesJson', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByArcSummariesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'arcSummariesJson', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByChapterCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterCount', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByChapterCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterCount', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByCharacterAge() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterAge', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByCharacterAgeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterAge', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByCharacterId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterId', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByCharacterIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterId', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByCharacterName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterName', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByCharacterNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterName', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByCharacterStateJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterStateJson', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByCharacterStateJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterStateJson', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByChronicleId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chronicleId', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByChronicleIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chronicleId', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByCoverImageBase64() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverImageBase64', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByCoverImageBase64Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverImageBase64', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy> sortByGenre() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genre', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy> sortByGenreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genre', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy> sortByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByLastChapterEnding() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastChapterEnding', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByLastChapterEndingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastChapterEnding', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByLastChoiceMade() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastChoiceMade', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByLastChoiceMadeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastChoiceMade', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByLastPlayedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPlayedAt', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByLastPlayedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPlayedAt', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByRecentMemoriesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recentMemoriesJson', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByRecentMemoriesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recentMemoriesJson', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByUnresolvedThreadsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unresolvedThreadsJson', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByUnresolvedThreadsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unresolvedThreadsJson', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByWorldFactsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'worldFactsJson', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      sortByWorldFactsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'worldFactsJson', Sort.desc);
    });
  }
}

extension ChronicleLocalQuerySortThenBy
    on QueryBuilder<ChronicleLocal, ChronicleLocal, QSortThenBy> {
  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByArcSummariesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'arcSummariesJson', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByArcSummariesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'arcSummariesJson', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByChapterCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterCount', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByChapterCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterCount', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByCharacterAge() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterAge', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByCharacterAgeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterAge', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByCharacterId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterId', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByCharacterIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterId', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByCharacterName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterName', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByCharacterNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterName', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByCharacterStateJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterStateJson', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByCharacterStateJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterStateJson', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByChronicleId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chronicleId', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByChronicleIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chronicleId', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByCoverImageBase64() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverImageBase64', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByCoverImageBase64Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverImageBase64', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy> thenByGenre() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genre', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy> thenByGenreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genre', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy> thenByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByLastChapterEnding() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastChapterEnding', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByLastChapterEndingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastChapterEnding', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByLastChoiceMade() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastChoiceMade', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByLastChoiceMadeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastChoiceMade', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByLastPlayedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPlayedAt', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByLastPlayedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPlayedAt', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByRecentMemoriesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recentMemoriesJson', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByRecentMemoriesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recentMemoriesJson', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByUnresolvedThreadsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unresolvedThreadsJson', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByUnresolvedThreadsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unresolvedThreadsJson', Sort.desc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByWorldFactsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'worldFactsJson', Sort.asc);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QAfterSortBy>
      thenByWorldFactsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'worldFactsJson', Sort.desc);
    });
  }
}

extension ChronicleLocalQueryWhereDistinct
    on QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct> {
  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct>
      distinctByArcSummariesJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'arcSummariesJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct>
      distinctByChapterCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chapterCount');
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct>
      distinctByCharacterAge() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'characterAge');
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct> distinctByCharacterId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'characterId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct>
      distinctByCharacterName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'characterName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct>
      distinctByCharacterStateJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'characterStateJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct> distinctByChronicleId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chronicleId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct>
      distinctByCoverImageBase64({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'coverImageBase64',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct> distinctByGenre(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'genre', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct> distinctByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isActive');
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct>
      distinctByLastChapterEnding({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastChapterEnding',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct>
      distinctByLastChoiceMade({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastChoiceMade',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct>
      distinctByLastPlayedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastPlayedAt');
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct>
      distinctByRecentMemoriesJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recentMemoriesJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct>
      distinctByUnresolvedThreadsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'unresolvedThreadsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChronicleLocal, ChronicleLocal, QDistinct>
      distinctByWorldFactsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'worldFactsJson',
          caseSensitive: caseSensitive);
    });
  }
}

extension ChronicleLocalQueryProperty
    on QueryBuilder<ChronicleLocal, ChronicleLocal, QQueryProperty> {
  QueryBuilder<ChronicleLocal, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChronicleLocal, String?, QQueryOperations>
      arcSummariesJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'arcSummariesJson');
    });
  }

  QueryBuilder<ChronicleLocal, int, QQueryOperations> chapterCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chapterCount');
    });
  }

  QueryBuilder<ChronicleLocal, int, QQueryOperations> characterAgeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'characterAge');
    });
  }

  QueryBuilder<ChronicleLocal, String, QQueryOperations> characterIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'characterId');
    });
  }

  QueryBuilder<ChronicleLocal, String, QQueryOperations>
      characterNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'characterName');
    });
  }

  QueryBuilder<ChronicleLocal, String?, QQueryOperations>
      characterStateJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'characterStateJson');
    });
  }

  QueryBuilder<ChronicleLocal, String, QQueryOperations> chronicleIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chronicleId');
    });
  }

  QueryBuilder<ChronicleLocal, String?, QQueryOperations>
      coverImageBase64Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'coverImageBase64');
    });
  }

  QueryBuilder<ChronicleLocal, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<ChronicleLocal, String, QQueryOperations> genreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'genre');
    });
  }

  QueryBuilder<ChronicleLocal, bool, QQueryOperations> isActiveProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isActive');
    });
  }

  QueryBuilder<ChronicleLocal, String?, QQueryOperations>
      lastChapterEndingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastChapterEnding');
    });
  }

  QueryBuilder<ChronicleLocal, String?, QQueryOperations>
      lastChoiceMadeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastChoiceMade');
    });
  }

  QueryBuilder<ChronicleLocal, DateTime, QQueryOperations>
      lastPlayedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastPlayedAt');
    });
  }

  QueryBuilder<ChronicleLocal, String?, QQueryOperations>
      recentMemoriesJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recentMemoriesJson');
    });
  }

  QueryBuilder<ChronicleLocal, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<ChronicleLocal, String?, QQueryOperations>
      unresolvedThreadsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'unresolvedThreadsJson');
    });
  }

  QueryBuilder<ChronicleLocal, String?, QQueryOperations>
      worldFactsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'worldFactsJson');
    });
  }
}
