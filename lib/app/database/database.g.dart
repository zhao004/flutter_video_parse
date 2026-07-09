// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ParseLogsTable extends ParseLogs
    with TableInfo<$ParseLogsTable, ParseLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParseLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> createdAt =
      GeneratedColumn<DateTime>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ParseLogsTable.$convertercreatedAt);
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _badgeMeta = const VerificationMeta('badge');
  @override
  late final GeneratedColumn<String> badge = GeneratedColumn<String>(
    'badge',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    level,
    title,
    description,
    source,
    badge,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parse_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ParseLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('badge')) {
      context.handle(
        _badgeMeta,
        badge.isAcceptableOrUnknown(data['badge']!, _badgeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ParseLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ParseLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAt: $ParseLogsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      badge: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}badge'],
      )!,
    );
  }

  @override
  $ParseLogsTable createAlias(String alias) {
    return $ParseLogsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, DateTime> $convertercreatedAt =
      const UtcDateTimeConverter();
}

class ParseLog extends DataClass implements Insertable<ParseLog> {
  final int id;
  final DateTime createdAt;
  final String level;
  final String title;
  final String description;
  final String source;
  final String badge;
  const ParseLog({
    required this.id,
    required this.createdAt,
    required this.level,
    required this.title,
    required this.description,
    required this.source,
    required this.badge,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['created_at'] = Variable<DateTime>(
        $ParseLogsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    map['level'] = Variable<String>(level);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['source'] = Variable<String>(source);
    map['badge'] = Variable<String>(badge);
    return map;
  }

  ParseLogsCompanion toCompanion(bool nullToAbsent) {
    return ParseLogsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      level: Value(level),
      title: Value(title),
      description: Value(description),
      source: Value(source),
      badge: Value(badge),
    );
  }

  factory ParseLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ParseLog(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      level: serializer.fromJson<String>(json['level']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      source: serializer.fromJson<String>(json['source']),
      badge: serializer.fromJson<String>(json['badge']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'level': serializer.toJson<String>(level),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'source': serializer.toJson<String>(source),
      'badge': serializer.toJson<String>(badge),
    };
  }

  ParseLog copyWith({
    int? id,
    DateTime? createdAt,
    String? level,
    String? title,
    String? description,
    String? source,
    String? badge,
  }) => ParseLog(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    level: level ?? this.level,
    title: title ?? this.title,
    description: description ?? this.description,
    source: source ?? this.source,
    badge: badge ?? this.badge,
  );
  ParseLog copyWithCompanion(ParseLogsCompanion data) {
    return ParseLog(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      level: data.level.present ? data.level.value : this.level,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      source: data.source.present ? data.source.value : this.source,
      badge: data.badge.present ? data.badge.value : this.badge,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ParseLog(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('level: $level, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('source: $source, ')
          ..write('badge: $badge')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, createdAt, level, title, description, source, badge);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParseLog &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.level == this.level &&
          other.title == this.title &&
          other.description == this.description &&
          other.source == this.source &&
          other.badge == this.badge);
}

class ParseLogsCompanion extends UpdateCompanion<ParseLog> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<String> level;
  final Value<String> title;
  final Value<String> description;
  final Value<String> source;
  final Value<String> badge;
  const ParseLogsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.level = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.source = const Value.absent(),
    this.badge = const Value.absent(),
  });
  ParseLogsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime createdAt,
    required String level,
    required String title,
    required String description,
    this.source = const Value.absent(),
    this.badge = const Value.absent(),
  }) : createdAt = Value(createdAt),
       level = Value(level),
       title = Value(title),
       description = Value(description);
  static Insertable<ParseLog> custom({
    Expression<int>? id,
    Expression<DateTime>? createdAt,
    Expression<String>? level,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? source,
    Expression<String>? badge,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (level != null) 'level': level,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (source != null) 'source': source,
      if (badge != null) 'badge': badge,
    });
  }

  ParseLogsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? createdAt,
    Value<String>? level,
    Value<String>? title,
    Value<String>? description,
    Value<String>? source,
    Value<String>? badge,
  }) {
    return ParseLogsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      level: level ?? this.level,
      title: title ?? this.title,
      description: description ?? this.description,
      source: source ?? this.source,
      badge: badge ?? this.badge,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(
        $ParseLogsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (badge.present) {
      map['badge'] = Variable<String>(badge.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParseLogsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('level: $level, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('source: $source, ')
          ..write('badge: $badge')
          ..write(')'))
        .toString();
  }
}

class $ParseResultCachesTable extends ParseResultCaches
    with TableInfo<$ParseResultCachesTable, ParseResultCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParseResultCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputUrlMeta = const VerificationMeta(
    'inputUrl',
  );
  @override
  late final GeneratedColumn<String> inputUrl = GeneratedColumn<String>(
    'input_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerNameMeta = const VerificationMeta(
    'providerName',
  );
  @override
  late final GeneratedColumn<String> providerName = GeneratedColumn<String>(
    'provider_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultJsonMeta = const VerificationMeta(
    'resultJson',
  );
  @override
  late final GeneratedColumn<String> resultJson = GeneratedColumn<String>(
    'result_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> createdAt =
      GeneratedColumn<DateTime>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ParseResultCachesTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> expiresAt =
      GeneratedColumn<DateTime>(
        'expires_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ParseResultCachesTable.$converterexpiresAt);
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    inputUrl,
    providerName,
    resultJson,
    createdAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parse_result_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<ParseResultCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('input_url')) {
      context.handle(
        _inputUrlMeta,
        inputUrl.isAcceptableOrUnknown(data['input_url']!, _inputUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_inputUrlMeta);
    }
    if (data.containsKey('provider_name')) {
      context.handle(
        _providerNameMeta,
        providerName.isAcceptableOrUnknown(
          data['provider_name']!,
          _providerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerNameMeta);
    }
    if (data.containsKey('result_json')) {
      context.handle(
        _resultJsonMeta,
        resultJson.isAcceptableOrUnknown(data['result_json']!, _resultJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_resultJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  ParseResultCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ParseResultCache(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      inputUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_url'],
      )!,
      providerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_name'],
      )!,
      resultJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_json'],
      )!,
      createdAt: $ParseResultCachesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      expiresAt: $ParseResultCachesTable.$converterexpiresAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}expires_at'],
        )!,
      ),
    );
  }

  @override
  $ParseResultCachesTable createAlias(String alias) {
    return $ParseResultCachesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, DateTime> $convertercreatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, DateTime> $converterexpiresAt =
      const UtcDateTimeConverter();
}

class ParseResultCache extends DataClass
    implements Insertable<ParseResultCache> {
  final String cacheKey;
  final String inputUrl;
  final String providerName;
  final String resultJson;
  final DateTime createdAt;
  final DateTime expiresAt;
  const ParseResultCache({
    required this.cacheKey,
    required this.inputUrl,
    required this.providerName,
    required this.resultJson,
    required this.createdAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['input_url'] = Variable<String>(inputUrl);
    map['provider_name'] = Variable<String>(providerName);
    map['result_json'] = Variable<String>(resultJson);
    {
      map['created_at'] = Variable<DateTime>(
        $ParseResultCachesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['expires_at'] = Variable<DateTime>(
        $ParseResultCachesTable.$converterexpiresAt.toSql(expiresAt),
      );
    }
    return map;
  }

  ParseResultCachesCompanion toCompanion(bool nullToAbsent) {
    return ParseResultCachesCompanion(
      cacheKey: Value(cacheKey),
      inputUrl: Value(inputUrl),
      providerName: Value(providerName),
      resultJson: Value(resultJson),
      createdAt: Value(createdAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory ParseResultCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ParseResultCache(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      inputUrl: serializer.fromJson<String>(json['inputUrl']),
      providerName: serializer.fromJson<String>(json['providerName']),
      resultJson: serializer.fromJson<String>(json['resultJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'inputUrl': serializer.toJson<String>(inputUrl),
      'providerName': serializer.toJson<String>(providerName),
      'resultJson': serializer.toJson<String>(resultJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  ParseResultCache copyWith({
    String? cacheKey,
    String? inputUrl,
    String? providerName,
    String? resultJson,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) => ParseResultCache(
    cacheKey: cacheKey ?? this.cacheKey,
    inputUrl: inputUrl ?? this.inputUrl,
    providerName: providerName ?? this.providerName,
    resultJson: resultJson ?? this.resultJson,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  ParseResultCache copyWithCompanion(ParseResultCachesCompanion data) {
    return ParseResultCache(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      inputUrl: data.inputUrl.present ? data.inputUrl.value : this.inputUrl,
      providerName: data.providerName.present
          ? data.providerName.value
          : this.providerName,
      resultJson: data.resultJson.present
          ? data.resultJson.value
          : this.resultJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ParseResultCache(')
          ..write('cacheKey: $cacheKey, ')
          ..write('inputUrl: $inputUrl, ')
          ..write('providerName: $providerName, ')
          ..write('resultJson: $resultJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    cacheKey,
    inputUrl,
    providerName,
    resultJson,
    createdAt,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParseResultCache &&
          other.cacheKey == this.cacheKey &&
          other.inputUrl == this.inputUrl &&
          other.providerName == this.providerName &&
          other.resultJson == this.resultJson &&
          other.createdAt == this.createdAt &&
          other.expiresAt == this.expiresAt);
}

class ParseResultCachesCompanion extends UpdateCompanion<ParseResultCache> {
  final Value<String> cacheKey;
  final Value<String> inputUrl;
  final Value<String> providerName;
  final Value<String> resultJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const ParseResultCachesCompanion({
    this.cacheKey = const Value.absent(),
    this.inputUrl = const Value.absent(),
    this.providerName = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ParseResultCachesCompanion.insert({
    required String cacheKey,
    required String inputUrl,
    required String providerName,
    required String resultJson,
    required DateTime createdAt,
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       inputUrl = Value(inputUrl),
       providerName = Value(providerName),
       resultJson = Value(resultJson),
       createdAt = Value(createdAt),
       expiresAt = Value(expiresAt);
  static Insertable<ParseResultCache> custom({
    Expression<String>? cacheKey,
    Expression<String>? inputUrl,
    Expression<String>? providerName,
    Expression<String>? resultJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (inputUrl != null) 'input_url': inputUrl,
      if (providerName != null) 'provider_name': providerName,
      if (resultJson != null) 'result_json': resultJson,
      if (createdAt != null) 'created_at': createdAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ParseResultCachesCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? inputUrl,
    Value<String>? providerName,
    Value<String>? resultJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? expiresAt,
    Value<int>? rowid,
  }) {
    return ParseResultCachesCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      inputUrl: inputUrl ?? this.inputUrl,
      providerName: providerName ?? this.providerName,
      resultJson: resultJson ?? this.resultJson,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (inputUrl.present) {
      map['input_url'] = Variable<String>(inputUrl.value);
    }
    if (providerName.present) {
      map['provider_name'] = Variable<String>(providerName.value);
    }
    if (resultJson.present) {
      map['result_json'] = Variable<String>(resultJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(
        $ParseResultCachesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(
        $ParseResultCachesTable.$converterexpiresAt.toSql(expiresAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParseResultCachesCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('inputUrl: $inputUrl, ')
          ..write('providerName: $providerName, ')
          ..write('resultJson: $resultJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ParseLogsTable parseLogs = $ParseLogsTable(this);
  late final $ParseResultCachesTable parseResultCaches =
      $ParseResultCachesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    parseLogs,
    parseResultCaches,
  ];
}

typedef $$ParseLogsTableCreateCompanionBuilder =
    ParseLogsCompanion Function({
      Value<int> id,
      required DateTime createdAt,
      required String level,
      required String title,
      required String description,
      Value<String> source,
      Value<String> badge,
    });
typedef $$ParseLogsTableUpdateCompanionBuilder =
    ParseLogsCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      Value<String> level,
      Value<String> title,
      Value<String> description,
      Value<String> source,
      Value<String> badge,
    });

class $$ParseLogsTableFilterComposer
    extends Composer<_$AppDatabase, $ParseLogsTable> {
  $$ParseLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get badge => $composableBuilder(
    column: $table.badge,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ParseLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $ParseLogsTable> {
  $$ParseLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get badge => $composableBuilder(
    column: $table.badge,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ParseLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParseLogsTable> {
  $$ParseLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get badge =>
      $composableBuilder(column: $table.badge, builder: (column) => column);
}

class $$ParseLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ParseLogsTable,
          ParseLog,
          $$ParseLogsTableFilterComposer,
          $$ParseLogsTableOrderingComposer,
          $$ParseLogsTableAnnotationComposer,
          $$ParseLogsTableCreateCompanionBuilder,
          $$ParseLogsTableUpdateCompanionBuilder,
          (ParseLog, BaseReferences<_$AppDatabase, $ParseLogsTable, ParseLog>),
          ParseLog,
          PrefetchHooks Function()
        > {
  $$ParseLogsTableTableManager(_$AppDatabase db, $ParseLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParseLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParseLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParseLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> badge = const Value.absent(),
              }) => ParseLogsCompanion(
                id: id,
                createdAt: createdAt,
                level: level,
                title: title,
                description: description,
                source: source,
                badge: badge,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime createdAt,
                required String level,
                required String title,
                required String description,
                Value<String> source = const Value.absent(),
                Value<String> badge = const Value.absent(),
              }) => ParseLogsCompanion.insert(
                id: id,
                createdAt: createdAt,
                level: level,
                title: title,
                description: description,
                source: source,
                badge: badge,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ParseLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ParseLogsTable,
      ParseLog,
      $$ParseLogsTableFilterComposer,
      $$ParseLogsTableOrderingComposer,
      $$ParseLogsTableAnnotationComposer,
      $$ParseLogsTableCreateCompanionBuilder,
      $$ParseLogsTableUpdateCompanionBuilder,
      (ParseLog, BaseReferences<_$AppDatabase, $ParseLogsTable, ParseLog>),
      ParseLog,
      PrefetchHooks Function()
    >;
typedef $$ParseResultCachesTableCreateCompanionBuilder =
    ParseResultCachesCompanion Function({
      required String cacheKey,
      required String inputUrl,
      required String providerName,
      required String resultJson,
      required DateTime createdAt,
      required DateTime expiresAt,
      Value<int> rowid,
    });
typedef $$ParseResultCachesTableUpdateCompanionBuilder =
    ParseResultCachesCompanion Function({
      Value<String> cacheKey,
      Value<String> inputUrl,
      Value<String> providerName,
      Value<String> resultJson,
      Value<DateTime> createdAt,
      Value<DateTime> expiresAt,
      Value<int> rowid,
    });

class $$ParseResultCachesTableFilterComposer
    extends Composer<_$AppDatabase, $ParseResultCachesTable> {
  $$ParseResultCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputUrl => $composableBuilder(
    column: $table.inputUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get expiresAt =>
      $composableBuilder(
        column: $table.expiresAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$ParseResultCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $ParseResultCachesTable> {
  $$ParseResultCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputUrl => $composableBuilder(
    column: $table.inputUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ParseResultCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParseResultCachesTable> {
  $$ParseResultCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get inputUrl =>
      $composableBuilder(column: $table.inputUrl, builder: (column) => column);

  GeneratedColumn<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$ParseResultCachesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ParseResultCachesTable,
          ParseResultCache,
          $$ParseResultCachesTableFilterComposer,
          $$ParseResultCachesTableOrderingComposer,
          $$ParseResultCachesTableAnnotationComposer,
          $$ParseResultCachesTableCreateCompanionBuilder,
          $$ParseResultCachesTableUpdateCompanionBuilder,
          (
            ParseResultCache,
            BaseReferences<
              _$AppDatabase,
              $ParseResultCachesTable,
              ParseResultCache
            >,
          ),
          ParseResultCache,
          PrefetchHooks Function()
        > {
  $$ParseResultCachesTableTableManager(
    _$AppDatabase db,
    $ParseResultCachesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParseResultCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParseResultCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParseResultCachesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String> inputUrl = const Value.absent(),
                Value<String> providerName = const Value.absent(),
                Value<String> resultJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ParseResultCachesCompanion(
                cacheKey: cacheKey,
                inputUrl: inputUrl,
                providerName: providerName,
                resultJson: resultJson,
                createdAt: createdAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String inputUrl,
                required String providerName,
                required String resultJson,
                required DateTime createdAt,
                required DateTime expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => ParseResultCachesCompanion.insert(
                cacheKey: cacheKey,
                inputUrl: inputUrl,
                providerName: providerName,
                resultJson: resultJson,
                createdAt: createdAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ParseResultCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ParseResultCachesTable,
      ParseResultCache,
      $$ParseResultCachesTableFilterComposer,
      $$ParseResultCachesTableOrderingComposer,
      $$ParseResultCachesTableAnnotationComposer,
      $$ParseResultCachesTableCreateCompanionBuilder,
      $$ParseResultCachesTableUpdateCompanionBuilder,
      (
        ParseResultCache,
        BaseReferences<
          _$AppDatabase,
          $ParseResultCachesTable,
          ParseResultCache
        >,
      ),
      ParseResultCache,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ParseLogsTableTableManager get parseLogs =>
      $$ParseLogsTableTableManager(_db, _db.parseLogs);
  $$ParseResultCachesTableTableManager get parseResultCaches =>
      $$ParseResultCachesTableTableManager(_db, _db.parseResultCaches);
}
