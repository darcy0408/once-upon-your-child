// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'avatar_cache_entry.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAvatarCacheEntryCollection on Isar {
  IsarCollection<AvatarCacheEntry> get avatarCacheEntrys => this.collection();
}

const AvatarCacheEntrySchema = CollectionSchema(
  name: r'AvatarCacheEntry',
  id: 12291683855250012,
  properties: {
    r'ageTier': PropertySchema(
      id: 0,
      name: r'ageTier',
      type: IsarType.string,
    ),
    r'cacheKey': PropertySchema(
      id: 1,
      name: r'cacheKey',
      type: IsarType.string,
    ),
    r'characterAge': PropertySchema(
      id: 2,
      name: r'characterAge',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 3,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'lastAccessedAt': PropertySchema(
      id: 4,
      name: r'lastAccessedAt',
      type: IsarType.dateTime,
    ),
    r'optionsJson': PropertySchema(
      id: 5,
      name: r'optionsJson',
      type: IsarType.string,
    ),
    r'schemaVersion': PropertySchema(
      id: 6,
      name: r'schemaVersion',
      type: IsarType.string,
    ),
    r'seed': PropertySchema(
      id: 7,
      name: r'seed',
      type: IsarType.string,
    ),
    r'style': PropertySchema(
      id: 8,
      name: r'style',
      type: IsarType.string,
    ),
    r'svgString': PropertySchema(
      id: 9,
      name: r'svgString',
      type: IsarType.string,
    )
  },
  estimateSize: _avatarCacheEntryEstimateSize,
  serialize: _avatarCacheEntrySerialize,
  deserialize: _avatarCacheEntryDeserialize,
  deserializeProp: _avatarCacheEntryDeserializeProp,
  idName: r'id',
  indexes: {
    r'cacheKey': IndexSchema(
      id: 5885332021012296610,
      name: r'cacheKey',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'cacheKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _avatarCacheEntryGetId,
  getLinks: _avatarCacheEntryGetLinks,
  attach: _avatarCacheEntryAttach,
  version: '3.1.0+1',
);

int _avatarCacheEntryEstimateSize(
  AvatarCacheEntry object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.ageTier;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.cacheKey.length * 3;
  {
    final value = object.optionsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.schemaVersion.length * 3;
  bytesCount += 3 + object.seed.length * 3;
  bytesCount += 3 + object.style.length * 3;
  bytesCount += 3 + object.svgString.length * 3;
  return bytesCount;
}

void _avatarCacheEntrySerialize(
  AvatarCacheEntry object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.ageTier);
  writer.writeString(offsets[1], object.cacheKey);
  writer.writeLong(offsets[2], object.characterAge);
  writer.writeDateTime(offsets[3], object.createdAt);
  writer.writeDateTime(offsets[4], object.lastAccessedAt);
  writer.writeString(offsets[5], object.optionsJson);
  writer.writeString(offsets[6], object.schemaVersion);
  writer.writeString(offsets[7], object.seed);
  writer.writeString(offsets[8], object.style);
  writer.writeString(offsets[9], object.svgString);
}

AvatarCacheEntry _avatarCacheEntryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AvatarCacheEntry();
  object.ageTier = reader.readStringOrNull(offsets[0]);
  object.cacheKey = reader.readString(offsets[1]);
  object.characterAge = reader.readLongOrNull(offsets[2]);
  object.createdAt = reader.readDateTime(offsets[3]);
  object.id = id;
  object.lastAccessedAt = reader.readDateTimeOrNull(offsets[4]);
  object.optionsJson = reader.readStringOrNull(offsets[5]);
  object.schemaVersion = reader.readString(offsets[6]);
  object.seed = reader.readString(offsets[7]);
  object.style = reader.readString(offsets[8]);
  object.svgString = reader.readString(offsets[9]);
  return object;
}

P _avatarCacheEntryDeserializeProp<P>(
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
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _avatarCacheEntryGetId(AvatarCacheEntry object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _avatarCacheEntryGetLinks(AvatarCacheEntry object) {
  return [];
}

void _avatarCacheEntryAttach(
    IsarCollection<dynamic> col, Id id, AvatarCacheEntry object) {
  object.id = id;
}

extension AvatarCacheEntryByIndex on IsarCollection<AvatarCacheEntry> {
  Future<AvatarCacheEntry?> getByCacheKey(String cacheKey) {
    return getByIndex(r'cacheKey', [cacheKey]);
  }

  AvatarCacheEntry? getByCacheKeySync(String cacheKey) {
    return getByIndexSync(r'cacheKey', [cacheKey]);
  }

  Future<bool> deleteByCacheKey(String cacheKey) {
    return deleteByIndex(r'cacheKey', [cacheKey]);
  }

  bool deleteByCacheKeySync(String cacheKey) {
    return deleteByIndexSync(r'cacheKey', [cacheKey]);
  }

  Future<List<AvatarCacheEntry?>> getAllByCacheKey(
      List<String> cacheKeyValues) {
    final values = cacheKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'cacheKey', values);
  }

  List<AvatarCacheEntry?> getAllByCacheKeySync(List<String> cacheKeyValues) {
    final values = cacheKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'cacheKey', values);
  }

  Future<int> deleteAllByCacheKey(List<String> cacheKeyValues) {
    final values = cacheKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'cacheKey', values);
  }

  int deleteAllByCacheKeySync(List<String> cacheKeyValues) {
    final values = cacheKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'cacheKey', values);
  }

  Future<Id> putByCacheKey(AvatarCacheEntry object) {
    return putByIndex(r'cacheKey', object);
  }

  Id putByCacheKeySync(AvatarCacheEntry object, {bool saveLinks = true}) {
    return putByIndexSync(r'cacheKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCacheKey(List<AvatarCacheEntry> objects) {
    return putAllByIndex(r'cacheKey', objects);
  }

  List<Id> putAllByCacheKeySync(List<AvatarCacheEntry> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'cacheKey', objects, saveLinks: saveLinks);
  }
}

extension AvatarCacheEntryQueryWhereSort
    on QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QWhere> {
  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AvatarCacheEntryQueryWhere
    on QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QWhereClause> {
  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterWhereClause>
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

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterWhereClause> idBetween(
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

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterWhereClause>
      cacheKeyEqualTo(String cacheKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'cacheKey',
        value: [cacheKey],
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterWhereClause>
      cacheKeyNotEqualTo(String cacheKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cacheKey',
              lower: [],
              upper: [cacheKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cacheKey',
              lower: [cacheKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cacheKey',
              lower: [cacheKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cacheKey',
              lower: [],
              upper: [cacheKey],
              includeUpper: false,
            ));
      }
    });
  }
}

extension AvatarCacheEntryQueryFilter
    on QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QFilterCondition> {
  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      ageTierIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'ageTier',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      ageTierIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'ageTier',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      ageTierEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ageTier',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      ageTierGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ageTier',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      ageTierLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ageTier',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      ageTierBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ageTier',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      ageTierStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ageTier',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      ageTierEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ageTier',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      ageTierContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ageTier',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      ageTierMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ageTier',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      ageTierIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ageTier',
        value: '',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      ageTierIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ageTier',
        value: '',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      cacheKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cacheKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      cacheKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cacheKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      cacheKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cacheKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      cacheKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cacheKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      cacheKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cacheKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      cacheKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cacheKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      cacheKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cacheKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      cacheKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cacheKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      cacheKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cacheKey',
        value: '',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      cacheKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cacheKey',
        value: '',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      characterAgeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'characterAge',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      characterAgeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'characterAge',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      characterAgeEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'characterAge',
        value: value,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      characterAgeGreaterThan(
    int? value, {
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

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      characterAgeLessThan(
    int? value, {
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

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      characterAgeBetween(
    int? lower,
    int? upper, {
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

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
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

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
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

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
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

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
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

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
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

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
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

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      lastAccessedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastAccessedAt',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      lastAccessedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastAccessedAt',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      lastAccessedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastAccessedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      lastAccessedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastAccessedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      lastAccessedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastAccessedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      lastAccessedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastAccessedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      optionsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'optionsJson',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      optionsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'optionsJson',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      optionsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'optionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      optionsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'optionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      optionsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'optionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      optionsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'optionsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      optionsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'optionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      optionsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'optionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      optionsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'optionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      optionsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'optionsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      optionsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'optionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      optionsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'optionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      schemaVersionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'schemaVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      schemaVersionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'schemaVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      schemaVersionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'schemaVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      schemaVersionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'schemaVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      schemaVersionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'schemaVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      schemaVersionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'schemaVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      schemaVersionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'schemaVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      schemaVersionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'schemaVersion',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      schemaVersionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'schemaVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      schemaVersionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'schemaVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      seedEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'seed',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      seedGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'seed',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      seedLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'seed',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      seedBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'seed',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      seedStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'seed',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      seedEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'seed',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      seedContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'seed',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      seedMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'seed',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      seedIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'seed',
        value: '',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      seedIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'seed',
        value: '',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      styleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'style',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      styleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'style',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      styleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'style',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      styleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'style',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      styleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'style',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      styleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'style',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      styleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'style',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      styleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'style',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      styleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'style',
        value: '',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      styleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'style',
        value: '',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      svgStringEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'svgString',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      svgStringGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'svgString',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      svgStringLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'svgString',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      svgStringBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'svgString',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      svgStringStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'svgString',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      svgStringEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'svgString',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      svgStringContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'svgString',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      svgStringMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'svgString',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      svgStringIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'svgString',
        value: '',
      ));
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterFilterCondition>
      svgStringIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'svgString',
        value: '',
      ));
    });
  }
}

extension AvatarCacheEntryQueryObject
    on QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QFilterCondition> {}

extension AvatarCacheEntryQueryLinks
    on QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QFilterCondition> {}

extension AvatarCacheEntryQuerySortBy
    on QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QSortBy> {
  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortByAgeTier() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ageTier', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortByAgeTierDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ageTier', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortByCacheKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cacheKey', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortByCacheKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cacheKey', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortByCharacterAge() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterAge', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortByCharacterAgeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterAge', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortByLastAccessedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAccessedAt', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortByLastAccessedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAccessedAt', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortByOptionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'optionsJson', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortByOptionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'optionsJson', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortBySchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy> sortBySeed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'seed', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortBySeedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'seed', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy> sortByStyle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'style', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortByStyleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'style', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortBySvgString() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'svgString', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      sortBySvgStringDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'svgString', Sort.desc);
    });
  }
}

extension AvatarCacheEntryQuerySortThenBy
    on QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QSortThenBy> {
  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenByAgeTier() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ageTier', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenByAgeTierDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ageTier', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenByCacheKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cacheKey', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenByCacheKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cacheKey', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenByCharacterAge() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterAge', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenByCharacterAgeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterAge', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenByLastAccessedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAccessedAt', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenByLastAccessedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAccessedAt', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenByOptionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'optionsJson', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenByOptionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'optionsJson', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenBySchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy> thenBySeed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'seed', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenBySeedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'seed', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy> thenByStyle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'style', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenByStyleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'style', Sort.desc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenBySvgString() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'svgString', Sort.asc);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QAfterSortBy>
      thenBySvgStringDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'svgString', Sort.desc);
    });
  }
}

extension AvatarCacheEntryQueryWhereDistinct
    on QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QDistinct> {
  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QDistinct> distinctByAgeTier(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ageTier', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QDistinct>
      distinctByCacheKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cacheKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QDistinct>
      distinctByCharacterAge() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'characterAge');
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QDistinct>
      distinctByLastAccessedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastAccessedAt');
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QDistinct>
      distinctByOptionsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'optionsJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QDistinct>
      distinctBySchemaVersion({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'schemaVersion',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QDistinct> distinctBySeed(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'seed', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QDistinct> distinctByStyle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'style', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QDistinct>
      distinctBySvgString({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'svgString', caseSensitive: caseSensitive);
    });
  }
}

extension AvatarCacheEntryQueryProperty
    on QueryBuilder<AvatarCacheEntry, AvatarCacheEntry, QQueryProperty> {
  QueryBuilder<AvatarCacheEntry, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AvatarCacheEntry, String?, QQueryOperations> ageTierProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ageTier');
    });
  }

  QueryBuilder<AvatarCacheEntry, String, QQueryOperations> cacheKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cacheKey');
    });
  }

  QueryBuilder<AvatarCacheEntry, int?, QQueryOperations>
      characterAgeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'characterAge');
    });
  }

  QueryBuilder<AvatarCacheEntry, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<AvatarCacheEntry, DateTime?, QQueryOperations>
      lastAccessedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastAccessedAt');
    });
  }

  QueryBuilder<AvatarCacheEntry, String?, QQueryOperations>
      optionsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'optionsJson');
    });
  }

  QueryBuilder<AvatarCacheEntry, String, QQueryOperations>
      schemaVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'schemaVersion');
    });
  }

  QueryBuilder<AvatarCacheEntry, String, QQueryOperations> seedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'seed');
    });
  }

  QueryBuilder<AvatarCacheEntry, String, QQueryOperations> styleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'style');
    });
  }

  QueryBuilder<AvatarCacheEntry, String, QQueryOperations> svgStringProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'svgString');
    });
  }
}
