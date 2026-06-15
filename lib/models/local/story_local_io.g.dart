// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'story_local_io.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetStoryLocalCollection on Isar {
  IsarCollection<StoryLocal> get storyLocals => this.collection();
}

const StoryLocalSchema = CollectionSchema(
  name: r'StoryLocal',
  id: -7044575653806414847,
  properties: {
    r'charactersJson': PropertySchema(
      id: 0,
      name: r'charactersJson',
      type: IsarType.string,
    ),
    r'coverImageBase64': PropertySchema(
      id: 1,
      name: r'coverImageBase64',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 2,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'currentSegmentNumber': PropertySchema(
      id: 3,
      name: r'currentSegmentNumber',
      type: IsarType.long,
    ),
    r'imageUrl': PropertySchema(
      id: 4,
      name: r'imageUrl',
      type: IsarType.string,
    ),
    r'inventoryJson': PropertySchema(
      id: 5,
      name: r'inventoryJson',
      type: IsarType.string,
    ),
    r'isCompleted': PropertySchema(
      id: 6,
      name: r'isCompleted',
      type: IsarType.bool,
    ),
    r'isFavorite': PropertySchema(
      id: 7,
      name: r'isFavorite',
      type: IsarType.bool,
    ),
    r'isInteractive': PropertySchema(
      id: 8,
      name: r'isInteractive',
      type: IsarType.bool,
    ),
    r'isLearningToRead': PropertySchema(
      id: 9,
      name: r'isLearningToRead',
      type: IsarType.bool,
    ),
    r'isRhyming': PropertySchema(
      id: 10,
      name: r'isRhyming',
      type: IsarType.bool,
    ),
    r'isSyncedToServer': PropertySchema(
      id: 11,
      name: r'isSyncedToServer',
      type: IsarType.bool,
    ),
    r'length': PropertySchema(
      id: 12,
      name: r'length',
      type: IsarType.string,
    ),
    r'pageIllustrationsJson': PropertySchema(
      id: 13,
      name: r'pageIllustrationsJson',
      type: IsarType.string,
    ),
    r'practiced': PropertySchema(
      id: 14,
      name: r'practiced',
      type: IsarType.string,
    ),
    r'stateJson': PropertySchema(
      id: 15,
      name: r'stateJson',
      type: IsarType.string,
    ),
    r'storyId': PropertySchema(
      id: 16,
      name: r'storyId',
      type: IsarType.string,
    ),
    r'storyText': PropertySchema(
      id: 17,
      name: r'storyText',
      type: IsarType.string,
    ),
    r'theme': PropertySchema(
      id: 18,
      name: r'theme',
      type: IsarType.string,
    ),
    r'title': PropertySchema(
      id: 19,
      name: r'title',
      type: IsarType.string,
    ),
    r'tone': PropertySchema(
      id: 20,
      name: r'tone',
      type: IsarType.string,
    ),
    r'wisdomGem': PropertySchema(
      id: 21,
      name: r'wisdomGem',
      type: IsarType.string,
    )
  },
  estimateSize: _storyLocalEstimateSize,
  serialize: _storyLocalSerialize,
  deserialize: _storyLocalDeserialize,
  deserializeProp: _storyLocalDeserializeProp,
  idName: r'id',
  indexes: {
    r'storyId': IndexSchema(
      id: -7904996416186759579,
      name: r'storyId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'storyId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'createdAt': IndexSchema(
      id: -3433535483987302584,
      name: r'createdAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'createdAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _storyLocalGetId,
  getLinks: _storyLocalGetLinks,
  attach: _storyLocalAttach,
  version: '3.1.0+1',
);

int _storyLocalEstimateSize(
  StoryLocal object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.charactersJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.coverImageBase64;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.imageUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.inventoryJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.length;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.pageIllustrationsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.practiced;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.stateJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.storyId.length * 3;
  bytesCount += 3 + object.storyText.length * 3;
  bytesCount += 3 + object.theme.length * 3;
  bytesCount += 3 + object.title.length * 3;
  {
    final value = object.tone;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.wisdomGem;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _storyLocalSerialize(
  StoryLocal object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.charactersJson);
  writer.writeString(offsets[1], object.coverImageBase64);
  writer.writeDateTime(offsets[2], object.createdAt);
  writer.writeLong(offsets[3], object.currentSegmentNumber);
  writer.writeString(offsets[4], object.imageUrl);
  writer.writeString(offsets[5], object.inventoryJson);
  writer.writeBool(offsets[6], object.isCompleted);
  writer.writeBool(offsets[7], object.isFavorite);
  writer.writeBool(offsets[8], object.isInteractive);
  writer.writeBool(offsets[9], object.isLearningToRead);
  writer.writeBool(offsets[10], object.isRhyming);
  writer.writeBool(offsets[11], object.isSyncedToServer);
  writer.writeString(offsets[12], object.length);
  writer.writeString(offsets[13], object.pageIllustrationsJson);
  writer.writeString(offsets[14], object.practiced);
  writer.writeString(offsets[15], object.stateJson);
  writer.writeString(offsets[16], object.storyId);
  writer.writeString(offsets[17], object.storyText);
  writer.writeString(offsets[18], object.theme);
  writer.writeString(offsets[19], object.title);
  writer.writeString(offsets[20], object.tone);
  writer.writeString(offsets[21], object.wisdomGem);
}

StoryLocal _storyLocalDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = StoryLocal();
  object.charactersJson = reader.readStringOrNull(offsets[0]);
  object.coverImageBase64 = reader.readStringOrNull(offsets[1]);
  object.createdAt = reader.readDateTime(offsets[2]);
  object.currentSegmentNumber = reader.readLongOrNull(offsets[3]);
  object.id = id;
  object.imageUrl = reader.readStringOrNull(offsets[4]);
  object.inventoryJson = reader.readStringOrNull(offsets[5]);
  object.isCompleted = reader.readBool(offsets[6]);
  object.isFavorite = reader.readBool(offsets[7]);
  object.isInteractive = reader.readBool(offsets[8]);
  object.isLearningToRead = reader.readBool(offsets[9]);
  object.isRhyming = reader.readBool(offsets[10]);
  object.isSyncedToServer = reader.readBool(offsets[11]);
  object.length = reader.readStringOrNull(offsets[12]);
  object.pageIllustrationsJson = reader.readStringOrNull(offsets[13]);
  object.practiced = reader.readStringOrNull(offsets[14]);
  object.stateJson = reader.readStringOrNull(offsets[15]);
  object.storyId = reader.readString(offsets[16]);
  object.storyText = reader.readString(offsets[17]);
  object.theme = reader.readString(offsets[18]);
  object.title = reader.readString(offsets[19]);
  object.tone = reader.readStringOrNull(offsets[20]);
  object.wisdomGem = reader.readStringOrNull(offsets[21]);
  return object;
}

P _storyLocalDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readBool(offset)) as P;
    case 9:
      return (reader.readBool(offset)) as P;
    case 10:
      return (reader.readBool(offset)) as P;
    case 11:
      return (reader.readBool(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readString(offset)) as P;
    case 17:
      return (reader.readString(offset)) as P;
    case 18:
      return (reader.readString(offset)) as P;
    case 19:
      return (reader.readString(offset)) as P;
    case 20:
      return (reader.readStringOrNull(offset)) as P;
    case 21:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _storyLocalGetId(StoryLocal object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _storyLocalGetLinks(StoryLocal object) {
  return [];
}

void _storyLocalAttach(IsarCollection<dynamic> col, Id id, StoryLocal object) {
  object.id = id;
}

extension StoryLocalQueryWhereSort
    on QueryBuilder<StoryLocal, StoryLocal, QWhere> {
  QueryBuilder<StoryLocal, StoryLocal, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterWhere> anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }
}

extension StoryLocalQueryWhere
    on QueryBuilder<StoryLocal, StoryLocal, QWhereClause> {
  QueryBuilder<StoryLocal, StoryLocal, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterWhereClause> idBetween(
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterWhereClause> storyIdEqualTo(
      String storyId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'storyId',
        value: [storyId],
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterWhereClause> storyIdNotEqualTo(
      String storyId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'storyId',
              lower: [],
              upper: [storyId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'storyId',
              lower: [storyId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'storyId',
              lower: [storyId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'storyId',
              lower: [],
              upper: [storyId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterWhereClause> createdAtEqualTo(
      DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'createdAt',
        value: [createdAt],
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterWhereClause> createdAtNotEqualTo(
      DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterWhereClause> createdAtGreaterThan(
    DateTime createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [createdAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterWhereClause> createdAtLessThan(
    DateTime createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [],
        upper: [createdAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterWhereClause> createdAtBetween(
    DateTime lowerCreatedAt,
    DateTime upperCreatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [lowerCreatedAt],
        includeLower: includeLower,
        upper: [upperCreatedAt],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension StoryLocalQueryFilter
    on QueryBuilder<StoryLocal, StoryLocal, QFilterCondition> {
  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      charactersJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'charactersJson',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      charactersJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'charactersJson',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      charactersJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'charactersJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      charactersJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'charactersJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      charactersJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'charactersJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      charactersJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'charactersJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      charactersJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'charactersJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      charactersJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'charactersJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      charactersJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'charactersJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      charactersJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'charactersJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      charactersJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'charactersJson',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      charactersJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'charactersJson',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      coverImageBase64IsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'coverImageBase64',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      coverImageBase64IsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'coverImageBase64',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      coverImageBase64Contains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'coverImageBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      coverImageBase64Matches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'coverImageBase64',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      coverImageBase64IsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'coverImageBase64',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      coverImageBase64IsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'coverImageBase64',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> createdAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> createdAtLessThan(
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> createdAtBetween(
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      currentSegmentNumberIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'currentSegmentNumber',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      currentSegmentNumberIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'currentSegmentNumber',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      currentSegmentNumberEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'currentSegmentNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      currentSegmentNumberGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'currentSegmentNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      currentSegmentNumberLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'currentSegmentNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      currentSegmentNumberBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'currentSegmentNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> idBetween(
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> imageUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'imageUrl',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      imageUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'imageUrl',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> imageUrlEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      imageUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'imageUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> imageUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'imageUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> imageUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'imageUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      imageUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'imageUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> imageUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'imageUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> imageUrlContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'imageUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> imageUrlMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'imageUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      imageUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      imageUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'imageUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      inventoryJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'inventoryJson',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      inventoryJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'inventoryJson',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      inventoryJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'inventoryJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      inventoryJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'inventoryJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      inventoryJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'inventoryJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      inventoryJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'inventoryJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      inventoryJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'inventoryJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      inventoryJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'inventoryJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      inventoryJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'inventoryJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      inventoryJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'inventoryJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      inventoryJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'inventoryJson',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      inventoryJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'inventoryJson',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      isCompletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isCompleted',
        value: value,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> isFavoriteEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isFavorite',
        value: value,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      isInteractiveEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isInteractive',
        value: value,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      isLearningToReadEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isLearningToRead',
        value: value,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> isRhymingEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isRhyming',
        value: value,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      isSyncedToServerEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSyncedToServer',
        value: value,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> lengthIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'length',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      lengthIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'length',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> lengthEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'length',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> lengthGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'length',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> lengthLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'length',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> lengthBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'length',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> lengthStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'length',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> lengthEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'length',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> lengthContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'length',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> lengthMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'length',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> lengthIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'length',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      lengthIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'length',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      pageIllustrationsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'pageIllustrationsJson',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      pageIllustrationsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'pageIllustrationsJson',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      pageIllustrationsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pageIllustrationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      pageIllustrationsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pageIllustrationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      pageIllustrationsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pageIllustrationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      pageIllustrationsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pageIllustrationsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      pageIllustrationsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'pageIllustrationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      pageIllustrationsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'pageIllustrationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      pageIllustrationsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'pageIllustrationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      pageIllustrationsJsonMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'pageIllustrationsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      pageIllustrationsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pageIllustrationsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      pageIllustrationsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'pageIllustrationsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      practicedIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'practiced',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      practicedIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'practiced',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> practicedEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'practiced',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      practicedGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'practiced',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> practicedLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'practiced',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> practicedBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'practiced',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      practicedStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'practiced',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> practicedEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'practiced',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> practicedContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'practiced',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> practicedMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'practiced',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      practicedIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'practiced',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      practicedIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'practiced',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      stateJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'stateJson',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      stateJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'stateJson',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> stateJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      stateJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'stateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> stateJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'stateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> stateJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'stateJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      stateJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'stateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> stateJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'stateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> stateJsonContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'stateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> stateJsonMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'stateJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      stateJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stateJson',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      stateJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'stateJson',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> storyIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storyId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      storyIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'storyId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> storyIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'storyId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> storyIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'storyId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> storyIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'storyId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> storyIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'storyId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> storyIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'storyId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> storyIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'storyId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> storyIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storyId',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      storyIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'storyId',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> storyTextEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storyText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      storyTextGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'storyText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> storyTextLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'storyText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> storyTextBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'storyText',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      storyTextStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'storyText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> storyTextEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'storyText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> storyTextContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'storyText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> storyTextMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'storyText',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      storyTextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storyText',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      storyTextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'storyText',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> themeEqualTo(
    String value, {
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> themeGreaterThan(
    String value, {
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> themeLessThan(
    String value, {
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> themeBetween(
    String lower,
    String upper, {
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> themeStartsWith(
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> themeEndsWith(
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> themeContains(
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> themeMatches(
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> themeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'theme',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      themeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'theme',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> titleEqualTo(
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> titleGreaterThan(
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> titleLessThan(
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> titleBetween(
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> titleStartsWith(
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> titleEndsWith(
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

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> titleContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> titleMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> toneIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'tone',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> toneIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'tone',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> toneEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> toneGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'tone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> toneLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'tone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> toneBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'tone',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> toneStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'tone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> toneEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'tone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> toneContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'tone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> toneMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'tone',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> toneIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tone',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> toneIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'tone',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      wisdomGemIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'wisdomGem',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      wisdomGemIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'wisdomGem',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> wisdomGemEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'wisdomGem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      wisdomGemGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'wisdomGem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> wisdomGemLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'wisdomGem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> wisdomGemBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'wisdomGem',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      wisdomGemStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'wisdomGem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> wisdomGemEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'wisdomGem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> wisdomGemContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'wisdomGem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition> wisdomGemMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'wisdomGem',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      wisdomGemIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'wisdomGem',
        value: '',
      ));
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterFilterCondition>
      wisdomGemIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'wisdomGem',
        value: '',
      ));
    });
  }
}

extension StoryLocalQueryObject
    on QueryBuilder<StoryLocal, StoryLocal, QFilterCondition> {}

extension StoryLocalQueryLinks
    on QueryBuilder<StoryLocal, StoryLocal, QFilterCondition> {}

extension StoryLocalQuerySortBy
    on QueryBuilder<StoryLocal, StoryLocal, QSortBy> {
  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByCharactersJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'charactersJson', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy>
      sortByCharactersJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'charactersJson', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByCoverImageBase64() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverImageBase64', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy>
      sortByCoverImageBase64Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverImageBase64', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy>
      sortByCurrentSegmentNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentSegmentNumber', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy>
      sortByCurrentSegmentNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentSegmentNumber', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByImageUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageUrl', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByImageUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageUrl', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByInventoryJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inventoryJson', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByInventoryJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inventoryJson', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByIsCompleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCompleted', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByIsCompletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCompleted', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByIsFavoriteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByIsInteractive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isInteractive', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByIsInteractiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isInteractive', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByIsLearningToRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLearningToRead', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy>
      sortByIsLearningToReadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLearningToRead', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByIsRhyming() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRhyming', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByIsRhymingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRhyming', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByIsSyncedToServer() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSyncedToServer', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy>
      sortByIsSyncedToServerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSyncedToServer', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'length', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'length', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy>
      sortByPageIllustrationsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageIllustrationsJson', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy>
      sortByPageIllustrationsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageIllustrationsJson', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByPracticed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'practiced', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByPracticedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'practiced', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByStateJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateJson', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByStateJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateJson', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByStoryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storyId', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByStoryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storyId', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByStoryText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storyText', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByStoryTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storyText', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByTheme() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'theme', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByThemeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'theme', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByTone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tone', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByToneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tone', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByWisdomGem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wisdomGem', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> sortByWisdomGemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wisdomGem', Sort.desc);
    });
  }
}

extension StoryLocalQuerySortThenBy
    on QueryBuilder<StoryLocal, StoryLocal, QSortThenBy> {
  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByCharactersJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'charactersJson', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy>
      thenByCharactersJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'charactersJson', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByCoverImageBase64() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverImageBase64', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy>
      thenByCoverImageBase64Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverImageBase64', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy>
      thenByCurrentSegmentNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentSegmentNumber', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy>
      thenByCurrentSegmentNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentSegmentNumber', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByImageUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageUrl', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByImageUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageUrl', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByInventoryJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inventoryJson', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByInventoryJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inventoryJson', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByIsCompleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCompleted', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByIsCompletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCompleted', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByIsFavoriteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByIsInteractive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isInteractive', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByIsInteractiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isInteractive', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByIsLearningToRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLearningToRead', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy>
      thenByIsLearningToReadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLearningToRead', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByIsRhyming() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRhyming', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByIsRhymingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRhyming', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByIsSyncedToServer() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSyncedToServer', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy>
      thenByIsSyncedToServerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSyncedToServer', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'length', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'length', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy>
      thenByPageIllustrationsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageIllustrationsJson', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy>
      thenByPageIllustrationsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageIllustrationsJson', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByPracticed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'practiced', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByPracticedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'practiced', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByStateJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateJson', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByStateJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateJson', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByStoryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storyId', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByStoryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storyId', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByStoryText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storyText', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByStoryTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storyText', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByTheme() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'theme', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByThemeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'theme', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByTone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tone', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByToneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tone', Sort.desc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByWisdomGem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wisdomGem', Sort.asc);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QAfterSortBy> thenByWisdomGemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wisdomGem', Sort.desc);
    });
  }
}

extension StoryLocalQueryWhereDistinct
    on QueryBuilder<StoryLocal, StoryLocal, QDistinct> {
  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByCharactersJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'charactersJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByCoverImageBase64(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'coverImageBase64',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct>
      distinctByCurrentSegmentNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'currentSegmentNumber');
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByImageUrl(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imageUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByInventoryJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'inventoryJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByIsCompleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isCompleted');
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isFavorite');
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByIsInteractive() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isInteractive');
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByIsLearningToRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isLearningToRead');
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByIsRhyming() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isRhyming');
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByIsSyncedToServer() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSyncedToServer');
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByLength(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'length', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct>
      distinctByPageIllustrationsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pageIllustrationsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByPracticed(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'practiced', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByStateJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stateJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByStoryId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'storyId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByStoryText(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'storyText', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByTheme(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'theme', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByTone(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tone', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoryLocal, StoryLocal, QDistinct> distinctByWisdomGem(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'wisdomGem', caseSensitive: caseSensitive);
    });
  }
}

extension StoryLocalQueryProperty
    on QueryBuilder<StoryLocal, StoryLocal, QQueryProperty> {
  QueryBuilder<StoryLocal, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<StoryLocal, String?, QQueryOperations> charactersJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'charactersJson');
    });
  }

  QueryBuilder<StoryLocal, String?, QQueryOperations>
      coverImageBase64Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'coverImageBase64');
    });
  }

  QueryBuilder<StoryLocal, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<StoryLocal, int?, QQueryOperations>
      currentSegmentNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'currentSegmentNumber');
    });
  }

  QueryBuilder<StoryLocal, String?, QQueryOperations> imageUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imageUrl');
    });
  }

  QueryBuilder<StoryLocal, String?, QQueryOperations> inventoryJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'inventoryJson');
    });
  }

  QueryBuilder<StoryLocal, bool, QQueryOperations> isCompletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isCompleted');
    });
  }

  QueryBuilder<StoryLocal, bool, QQueryOperations> isFavoriteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isFavorite');
    });
  }

  QueryBuilder<StoryLocal, bool, QQueryOperations> isInteractiveProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isInteractive');
    });
  }

  QueryBuilder<StoryLocal, bool, QQueryOperations> isLearningToReadProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isLearningToRead');
    });
  }

  QueryBuilder<StoryLocal, bool, QQueryOperations> isRhymingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isRhyming');
    });
  }

  QueryBuilder<StoryLocal, bool, QQueryOperations> isSyncedToServerProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSyncedToServer');
    });
  }

  QueryBuilder<StoryLocal, String?, QQueryOperations> lengthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'length');
    });
  }

  QueryBuilder<StoryLocal, String?, QQueryOperations>
      pageIllustrationsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pageIllustrationsJson');
    });
  }

  QueryBuilder<StoryLocal, String?, QQueryOperations> practicedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'practiced');
    });
  }

  QueryBuilder<StoryLocal, String?, QQueryOperations> stateJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stateJson');
    });
  }

  QueryBuilder<StoryLocal, String, QQueryOperations> storyIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'storyId');
    });
  }

  QueryBuilder<StoryLocal, String, QQueryOperations> storyTextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'storyText');
    });
  }

  QueryBuilder<StoryLocal, String, QQueryOperations> themeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'theme');
    });
  }

  QueryBuilder<StoryLocal, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<StoryLocal, String?, QQueryOperations> toneProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tone');
    });
  }

  QueryBuilder<StoryLocal, String?, QQueryOperations> wisdomGemProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'wisdomGem');
    });
  }
}
