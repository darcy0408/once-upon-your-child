// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chapter_memory_local_io.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChapterMemoryLocalCollection on Isar {
  IsarCollection<ChapterMemoryLocal> get chapterMemoryLocals =>
      this.collection();
}

const ChapterMemoryLocalSchema = CollectionSchema(
  name: r'ChapterMemoryLocal',
  id: 4533444453014402822,
  properties: {
    r'chapterNumber': PropertySchema(
      id: 0,
      name: r'chapterNumber',
      type: IsarType.long,
    ),
    r'characterGrowthNote': PropertySchema(
      id: 1,
      name: r'characterGrowthNote',
      type: IsarType.string,
    ),
    r'choiceMadeToStartChapter': PropertySchema(
      id: 2,
      name: r'choiceMadeToStartChapter',
      type: IsarType.string,
    ),
    r'chronicleId': PropertySchema(
      id: 3,
      name: r'chronicleId',
      type: IsarType.string,
    ),
    r'cliffhanger': PropertySchema(
      id: 4,
      name: r'cliffhanger',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 5,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'fullChapterText': PropertySchema(
      id: 6,
      name: r'fullChapterText',
      type: IsarType.string,
    ),
    r'newThreadsJson': PropertySchema(
      id: 7,
      name: r'newThreadsJson',
      type: IsarType.string,
    ),
    r'newWorldFactsJson': PropertySchema(
      id: 8,
      name: r'newWorldFactsJson',
      type: IsarType.string,
    ),
    r'resolvedThreadsJson': PropertySchema(
      id: 9,
      name: r'resolvedThreadsJson',
      type: IsarType.string,
    ),
    r'summaryBulletsJson': PropertySchema(
      id: 10,
      name: r'summaryBulletsJson',
      type: IsarType.string,
    )
  },
  estimateSize: _chapterMemoryLocalEstimateSize,
  serialize: _chapterMemoryLocalSerialize,
  deserialize: _chapterMemoryLocalDeserialize,
  deserializeProp: _chapterMemoryLocalDeserializeProp,
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
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _chapterMemoryLocalGetId,
  getLinks: _chapterMemoryLocalGetLinks,
  attach: _chapterMemoryLocalAttach,
  version: '3.1.0+1',
);

int _chapterMemoryLocalEstimateSize(
  ChapterMemoryLocal object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.characterGrowthNote;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.choiceMadeToStartChapter;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.chronicleId.length * 3;
  {
    final value = object.cliffhanger;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.fullChapterText;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.newThreadsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.newWorldFactsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.resolvedThreadsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.summaryBulletsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _chapterMemoryLocalSerialize(
  ChapterMemoryLocal object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.chapterNumber);
  writer.writeString(offsets[1], object.characterGrowthNote);
  writer.writeString(offsets[2], object.choiceMadeToStartChapter);
  writer.writeString(offsets[3], object.chronicleId);
  writer.writeString(offsets[4], object.cliffhanger);
  writer.writeDateTime(offsets[5], object.createdAt);
  writer.writeString(offsets[6], object.fullChapterText);
  writer.writeString(offsets[7], object.newThreadsJson);
  writer.writeString(offsets[8], object.newWorldFactsJson);
  writer.writeString(offsets[9], object.resolvedThreadsJson);
  writer.writeString(offsets[10], object.summaryBulletsJson);
}

ChapterMemoryLocal _chapterMemoryLocalDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChapterMemoryLocal();
  object.chapterNumber = reader.readLong(offsets[0]);
  object.characterGrowthNote = reader.readStringOrNull(offsets[1]);
  object.choiceMadeToStartChapter = reader.readStringOrNull(offsets[2]);
  object.chronicleId = reader.readString(offsets[3]);
  object.cliffhanger = reader.readStringOrNull(offsets[4]);
  object.createdAt = reader.readDateTime(offsets[5]);
  object.fullChapterText = reader.readStringOrNull(offsets[6]);
  object.id = id;
  object.newThreadsJson = reader.readStringOrNull(offsets[7]);
  object.newWorldFactsJson = reader.readStringOrNull(offsets[8]);
  object.resolvedThreadsJson = reader.readStringOrNull(offsets[9]);
  object.summaryBulletsJson = reader.readStringOrNull(offsets[10]);
  return object;
}

P _chapterMemoryLocalDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readDateTime(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chapterMemoryLocalGetId(ChapterMemoryLocal object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chapterMemoryLocalGetLinks(
    ChapterMemoryLocal object) {
  return [];
}

void _chapterMemoryLocalAttach(
    IsarCollection<dynamic> col, Id id, ChapterMemoryLocal object) {
  object.id = id;
}

extension ChapterMemoryLocalQueryWhereSort
    on QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QWhere> {
  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ChapterMemoryLocalQueryWhere
    on QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QWhereClause> {
  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterWhereClause>
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

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterWhereClause>
      idBetween(
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

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterWhereClause>
      chronicleIdEqualTo(String chronicleId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'chronicleId',
        value: [chronicleId],
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterWhereClause>
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
}

extension ChapterMemoryLocalQueryFilter
    on QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QFilterCondition> {
  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      chapterNumberEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chapterNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      chapterNumberGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chapterNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      chapterNumberLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chapterNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      chapterNumberBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chapterNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      characterGrowthNoteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'characterGrowthNote',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      characterGrowthNoteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'characterGrowthNote',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      characterGrowthNoteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'characterGrowthNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      characterGrowthNoteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'characterGrowthNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      characterGrowthNoteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'characterGrowthNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      characterGrowthNoteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'characterGrowthNote',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      characterGrowthNoteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'characterGrowthNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      characterGrowthNoteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'characterGrowthNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      characterGrowthNoteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'characterGrowthNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      characterGrowthNoteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'characterGrowthNote',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      characterGrowthNoteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'characterGrowthNote',
        value: '',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      characterGrowthNoteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'characterGrowthNote',
        value: '',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      choiceMadeToStartChapterIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'choiceMadeToStartChapter',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      choiceMadeToStartChapterIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'choiceMadeToStartChapter',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      choiceMadeToStartChapterEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'choiceMadeToStartChapter',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      choiceMadeToStartChapterGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'choiceMadeToStartChapter',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      choiceMadeToStartChapterLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'choiceMadeToStartChapter',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      choiceMadeToStartChapterBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'choiceMadeToStartChapter',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      choiceMadeToStartChapterStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'choiceMadeToStartChapter',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      choiceMadeToStartChapterEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'choiceMadeToStartChapter',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      choiceMadeToStartChapterContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'choiceMadeToStartChapter',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      choiceMadeToStartChapterMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'choiceMadeToStartChapter',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      choiceMadeToStartChapterIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'choiceMadeToStartChapter',
        value: '',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      choiceMadeToStartChapterIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'choiceMadeToStartChapter',
        value: '',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
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

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
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

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
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

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
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

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
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

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
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

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      chronicleIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'chronicleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      chronicleIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'chronicleId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      chronicleIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chronicleId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      chronicleIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'chronicleId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      cliffhangerIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'cliffhanger',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      cliffhangerIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'cliffhanger',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      cliffhangerEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cliffhanger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      cliffhangerGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cliffhanger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      cliffhangerLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cliffhanger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      cliffhangerBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cliffhanger',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      cliffhangerStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cliffhanger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      cliffhangerEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cliffhanger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      cliffhangerContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cliffhanger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      cliffhangerMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cliffhanger',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      cliffhangerIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cliffhanger',
        value: '',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      cliffhangerIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cliffhanger',
        value: '',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
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

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
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

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
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

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      fullChapterTextIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'fullChapterText',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      fullChapterTextIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'fullChapterText',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      fullChapterTextEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fullChapterText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      fullChapterTextGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fullChapterText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      fullChapterTextLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fullChapterText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      fullChapterTextBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fullChapterText',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      fullChapterTextStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'fullChapterText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      fullChapterTextEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'fullChapterText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      fullChapterTextContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'fullChapterText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      fullChapterTextMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'fullChapterText',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      fullChapterTextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fullChapterText',
        value: '',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      fullChapterTextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'fullChapterText',
        value: '',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
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

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
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

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
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

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newThreadsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'newThreadsJson',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newThreadsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'newThreadsJson',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newThreadsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'newThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newThreadsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'newThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newThreadsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'newThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newThreadsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'newThreadsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newThreadsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'newThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newThreadsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'newThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newThreadsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'newThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newThreadsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'newThreadsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newThreadsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'newThreadsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newThreadsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'newThreadsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newWorldFactsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'newWorldFactsJson',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newWorldFactsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'newWorldFactsJson',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newWorldFactsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'newWorldFactsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newWorldFactsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'newWorldFactsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newWorldFactsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'newWorldFactsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newWorldFactsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'newWorldFactsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newWorldFactsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'newWorldFactsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newWorldFactsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'newWorldFactsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newWorldFactsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'newWorldFactsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newWorldFactsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'newWorldFactsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newWorldFactsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'newWorldFactsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      newWorldFactsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'newWorldFactsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      resolvedThreadsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'resolvedThreadsJson',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      resolvedThreadsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'resolvedThreadsJson',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      resolvedThreadsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      resolvedThreadsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resolvedThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      resolvedThreadsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resolvedThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      resolvedThreadsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resolvedThreadsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      resolvedThreadsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'resolvedThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      resolvedThreadsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'resolvedThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      resolvedThreadsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resolvedThreadsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      resolvedThreadsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resolvedThreadsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      resolvedThreadsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedThreadsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      resolvedThreadsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resolvedThreadsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      summaryBulletsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'summaryBulletsJson',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      summaryBulletsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'summaryBulletsJson',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      summaryBulletsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'summaryBulletsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      summaryBulletsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'summaryBulletsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      summaryBulletsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'summaryBulletsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      summaryBulletsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'summaryBulletsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      summaryBulletsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'summaryBulletsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      summaryBulletsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'summaryBulletsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      summaryBulletsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'summaryBulletsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      summaryBulletsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'summaryBulletsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      summaryBulletsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'summaryBulletsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterFilterCondition>
      summaryBulletsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'summaryBulletsJson',
        value: '',
      ));
    });
  }
}

extension ChapterMemoryLocalQueryObject
    on QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QFilterCondition> {}

extension ChapterMemoryLocalQueryLinks
    on QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QFilterCondition> {}

extension ChapterMemoryLocalQuerySortBy
    on QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QSortBy> {
  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByChapterNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterNumber', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByChapterNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterNumber', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByCharacterGrowthNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterGrowthNote', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByCharacterGrowthNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterGrowthNote', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByChoiceMadeToStartChapter() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'choiceMadeToStartChapter', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByChoiceMadeToStartChapterDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'choiceMadeToStartChapter', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByChronicleId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chronicleId', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByChronicleIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chronicleId', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByCliffhanger() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cliffhanger', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByCliffhangerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cliffhanger', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByFullChapterText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fullChapterText', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByFullChapterTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fullChapterText', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByNewThreadsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newThreadsJson', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByNewThreadsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newThreadsJson', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByNewWorldFactsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newWorldFactsJson', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByNewWorldFactsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newWorldFactsJson', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByResolvedThreadsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedThreadsJson', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortByResolvedThreadsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedThreadsJson', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortBySummaryBulletsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summaryBulletsJson', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      sortBySummaryBulletsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summaryBulletsJson', Sort.desc);
    });
  }
}

extension ChapterMemoryLocalQuerySortThenBy
    on QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QSortThenBy> {
  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByChapterNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterNumber', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByChapterNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterNumber', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByCharacterGrowthNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterGrowthNote', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByCharacterGrowthNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterGrowthNote', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByChoiceMadeToStartChapter() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'choiceMadeToStartChapter', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByChoiceMadeToStartChapterDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'choiceMadeToStartChapter', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByChronicleId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chronicleId', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByChronicleIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chronicleId', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByCliffhanger() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cliffhanger', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByCliffhangerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cliffhanger', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByFullChapterText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fullChapterText', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByFullChapterTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fullChapterText', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByNewThreadsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newThreadsJson', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByNewThreadsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newThreadsJson', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByNewWorldFactsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newWorldFactsJson', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByNewWorldFactsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newWorldFactsJson', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByResolvedThreadsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedThreadsJson', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenByResolvedThreadsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedThreadsJson', Sort.desc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenBySummaryBulletsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summaryBulletsJson', Sort.asc);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QAfterSortBy>
      thenBySummaryBulletsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summaryBulletsJson', Sort.desc);
    });
  }
}

extension ChapterMemoryLocalQueryWhereDistinct
    on QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QDistinct> {
  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QDistinct>
      distinctByChapterNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chapterNumber');
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QDistinct>
      distinctByCharacterGrowthNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'characterGrowthNote',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QDistinct>
      distinctByChoiceMadeToStartChapter({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'choiceMadeToStartChapter',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QDistinct>
      distinctByChronicleId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chronicleId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QDistinct>
      distinctByCliffhanger({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cliffhanger', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QDistinct>
      distinctByFullChapterText({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fullChapterText',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QDistinct>
      distinctByNewThreadsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'newThreadsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QDistinct>
      distinctByNewWorldFactsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'newWorldFactsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QDistinct>
      distinctByResolvedThreadsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolvedThreadsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QDistinct>
      distinctBySummaryBulletsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'summaryBulletsJson',
          caseSensitive: caseSensitive);
    });
  }
}

extension ChapterMemoryLocalQueryProperty
    on QueryBuilder<ChapterMemoryLocal, ChapterMemoryLocal, QQueryProperty> {
  QueryBuilder<ChapterMemoryLocal, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChapterMemoryLocal, int, QQueryOperations>
      chapterNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chapterNumber');
    });
  }

  QueryBuilder<ChapterMemoryLocal, String?, QQueryOperations>
      characterGrowthNoteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'characterGrowthNote');
    });
  }

  QueryBuilder<ChapterMemoryLocal, String?, QQueryOperations>
      choiceMadeToStartChapterProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'choiceMadeToStartChapter');
    });
  }

  QueryBuilder<ChapterMemoryLocal, String, QQueryOperations>
      chronicleIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chronicleId');
    });
  }

  QueryBuilder<ChapterMemoryLocal, String?, QQueryOperations>
      cliffhangerProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cliffhanger');
    });
  }

  QueryBuilder<ChapterMemoryLocal, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<ChapterMemoryLocal, String?, QQueryOperations>
      fullChapterTextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fullChapterText');
    });
  }

  QueryBuilder<ChapterMemoryLocal, String?, QQueryOperations>
      newThreadsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'newThreadsJson');
    });
  }

  QueryBuilder<ChapterMemoryLocal, String?, QQueryOperations>
      newWorldFactsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'newWorldFactsJson');
    });
  }

  QueryBuilder<ChapterMemoryLocal, String?, QQueryOperations>
      resolvedThreadsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolvedThreadsJson');
    });
  }

  QueryBuilder<ChapterMemoryLocal, String?, QQueryOperations>
      summaryBulletsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'summaryBulletsJson');
    });
  }
}
