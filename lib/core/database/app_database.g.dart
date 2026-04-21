// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AppUsersTable extends AppUsers with TableInfo<$AppUsersTable, AppUser> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppUsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _usernameMeta =
      const VerificationMeta('username');
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
      'username', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _profileImageMeta =
      const VerificationMeta('profileImage');
  @override
  late final GeneratedColumn<String> profileImage = GeneratedColumn<String>(
      'profile_image', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isVerifiedMeta =
      const VerificationMeta('isVerified');
  @override
  late final GeneratedColumn<bool> isVerified = GeneratedColumn<bool>(
      'is_verified', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_verified" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, username, email, profileImage, isVerified, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_users';
  @override
  VerificationContext validateIntegrity(Insertable<AppUser> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('username')) {
      context.handle(_usernameMeta,
          username.isAcceptableOrUnknown(data['username']!, _usernameMeta));
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('profile_image')) {
      context.handle(
          _profileImageMeta,
          profileImage.isAcceptableOrUnknown(
              data['profile_image']!, _profileImageMeta));
    }
    if (data.containsKey('is_verified')) {
      context.handle(
          _isVerifiedMeta,
          isVerified.isAcceptableOrUnknown(
              data['is_verified']!, _isVerifiedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppUser map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppUser(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      username: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}username'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email'])!,
      profileImage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}profile_image']),
      isVerified: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_verified'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AppUsersTable createAlias(String alias) {
    return $AppUsersTable(attachedDatabase, alias);
  }
}

class AppUser extends DataClass implements Insertable<AppUser> {
  final String id;
  final String username;
  final String email;
  final String? profileImage;
  final bool isVerified;
  final DateTime createdAt;
  const AppUser(
      {required this.id,
      required this.username,
      required this.email,
      this.profileImage,
      required this.isVerified,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['username'] = Variable<String>(username);
    map['email'] = Variable<String>(email);
    if (!nullToAbsent || profileImage != null) {
      map['profile_image'] = Variable<String>(profileImage);
    }
    map['is_verified'] = Variable<bool>(isVerified);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AppUsersCompanion toCompanion(bool nullToAbsent) {
    return AppUsersCompanion(
      id: Value(id),
      username: Value(username),
      email: Value(email),
      profileImage: profileImage == null && nullToAbsent
          ? const Value.absent()
          : Value(profileImage),
      isVerified: Value(isVerified),
      createdAt: Value(createdAt),
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppUser(
      id: serializer.fromJson<String>(json['id']),
      username: serializer.fromJson<String>(json['username']),
      email: serializer.fromJson<String>(json['email']),
      profileImage: serializer.fromJson<String?>(json['profileImage']),
      isVerified: serializer.fromJson<bool>(json['isVerified']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'username': serializer.toJson<String>(username),
      'email': serializer.toJson<String>(email),
      'profileImage': serializer.toJson<String?>(profileImage),
      'isVerified': serializer.toJson<bool>(isVerified),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AppUser copyWith(
          {String? id,
          String? username,
          String? email,
          Value<String?> profileImage = const Value.absent(),
          bool? isVerified,
          DateTime? createdAt}) =>
      AppUser(
        id: id ?? this.id,
        username: username ?? this.username,
        email: email ?? this.email,
        profileImage:
            profileImage.present ? profileImage.value : this.profileImage,
        isVerified: isVerified ?? this.isVerified,
        createdAt: createdAt ?? this.createdAt,
      );
  AppUser copyWithCompanion(AppUsersCompanion data) {
    return AppUser(
      id: data.id.present ? data.id.value : this.id,
      username: data.username.present ? data.username.value : this.username,
      email: data.email.present ? data.email.value : this.email,
      profileImage: data.profileImage.present
          ? data.profileImage.value
          : this.profileImage,
      isVerified:
          data.isVerified.present ? data.isVerified.value : this.isVerified,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppUser(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('email: $email, ')
          ..write('profileImage: $profileImage, ')
          ..write('isVerified: $isVerified, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, username, email, profileImage, isVerified, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUser &&
          other.id == this.id &&
          other.username == this.username &&
          other.email == this.email &&
          other.profileImage == this.profileImage &&
          other.isVerified == this.isVerified &&
          other.createdAt == this.createdAt);
}

class AppUsersCompanion extends UpdateCompanion<AppUser> {
  final Value<String> id;
  final Value<String> username;
  final Value<String> email;
  final Value<String?> profileImage;
  final Value<bool> isVerified;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AppUsersCompanion({
    this.id = const Value.absent(),
    this.username = const Value.absent(),
    this.email = const Value.absent(),
    this.profileImage = const Value.absent(),
    this.isVerified = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppUsersCompanion.insert({
    required String id,
    required String username,
    required String email,
    this.profileImage = const Value.absent(),
    this.isVerified = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        username = Value(username),
        email = Value(email),
        createdAt = Value(createdAt);
  static Insertable<AppUser> custom({
    Expression<String>? id,
    Expression<String>? username,
    Expression<String>? email,
    Expression<String>? profileImage,
    Expression<bool>? isVerified,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (username != null) 'username': username,
      if (email != null) 'email': email,
      if (profileImage != null) 'profile_image': profileImage,
      if (isVerified != null) 'is_verified': isVerified,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppUsersCompanion copyWith(
      {Value<String>? id,
      Value<String>? username,
      Value<String>? email,
      Value<String?>? profileImage,
      Value<bool>? isVerified,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return AppUsersCompanion(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (profileImage.present) {
      map['profile_image'] = Variable<String>(profileImage.value);
    }
    if (isVerified.present) {
      map['is_verified'] = Variable<bool>(isVerified.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppUsersCompanion(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('email: $email, ')
          ..write('profileImage: $profileImage, ')
          ..write('isVerified: $isVerified, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PostsTable extends Posts with TableInfo<$PostsTable, Post> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _videoUrlMeta =
      const VerificationMeta('videoUrl');
  @override
  late final GeneratedColumn<String> videoUrl = GeneratedColumn<String>(
      'video_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationMeta =
      const VerificationMeta('location');
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
      'location', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _likesMeta = const VerificationMeta('likes');
  @override
  late final GeneratedColumn<int> likes = GeneratedColumn<int>(
      'likes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _commentsCountMeta =
      const VerificationMeta('commentsCount');
  @override
  late final GeneratedColumn<int> commentsCount = GeneratedColumn<int>(
      'comments_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _sharesMeta = const VerificationMeta('shares');
  @override
  late final GeneratedColumn<int> shares = GeneratedColumn<int>(
      'shares', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isEditedMeta =
      const VerificationMeta('isEdited');
  @override
  late final GeneratedColumn<bool> isEdited = GeneratedColumn<bool>(
      'is_edited', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_edited" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        content,
        imageUrl,
        videoUrl,
        location,
        likes,
        commentsCount,
        shares,
        isEdited,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'posts';
  @override
  VerificationContext validateIntegrity(Insertable<Post> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('video_url')) {
      context.handle(_videoUrlMeta,
          videoUrl.isAcceptableOrUnknown(data['video_url']!, _videoUrlMeta));
    }
    if (data.containsKey('location')) {
      context.handle(_locationMeta,
          location.isAcceptableOrUnknown(data['location']!, _locationMeta));
    }
    if (data.containsKey('likes')) {
      context.handle(
          _likesMeta, likes.isAcceptableOrUnknown(data['likes']!, _likesMeta));
    }
    if (data.containsKey('comments_count')) {
      context.handle(
          _commentsCountMeta,
          commentsCount.isAcceptableOrUnknown(
              data['comments_count']!, _commentsCountMeta));
    }
    if (data.containsKey('shares')) {
      context.handle(_sharesMeta,
          shares.isAcceptableOrUnknown(data['shares']!, _sharesMeta));
    }
    if (data.containsKey('is_edited')) {
      context.handle(_isEditedMeta,
          isEdited.isAcceptableOrUnknown(data['is_edited']!, _isEditedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Post map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Post(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      videoUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_url']),
      location: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location']),
      likes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}likes'])!,
      commentsCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}comments_count'])!,
      shares: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}shares'])!,
      isEdited: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_edited'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PostsTable createAlias(String alias) {
    return $PostsTable(attachedDatabase, alias);
  }
}

class Post extends DataClass implements Insertable<Post> {
  final int id;
  final String userId;
  final String content;
  final String? imageUrl;
  final String? videoUrl;
  final String? location;
  final int likes;
  final int commentsCount;
  final int shares;
  final bool isEdited;
  final DateTime createdAt;
  const Post(
      {required this.id,
      required this.userId,
      required this.content,
      this.imageUrl,
      this.videoUrl,
      this.location,
      required this.likes,
      required this.commentsCount,
      required this.shares,
      required this.isEdited,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<String>(userId);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || videoUrl != null) {
      map['video_url'] = Variable<String>(videoUrl);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    map['likes'] = Variable<int>(likes);
    map['comments_count'] = Variable<int>(commentsCount);
    map['shares'] = Variable<int>(shares);
    map['is_edited'] = Variable<bool>(isEdited);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PostsCompanion toCompanion(bool nullToAbsent) {
    return PostsCompanion(
      id: Value(id),
      userId: Value(userId),
      content: Value(content),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      videoUrl: videoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(videoUrl),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      likes: Value(likes),
      commentsCount: Value(commentsCount),
      shares: Value(shares),
      isEdited: Value(isEdited),
      createdAt: Value(createdAt),
    );
  }

  factory Post.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Post(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      content: serializer.fromJson<String>(json['content']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      videoUrl: serializer.fromJson<String?>(json['videoUrl']),
      location: serializer.fromJson<String?>(json['location']),
      likes: serializer.fromJson<int>(json['likes']),
      commentsCount: serializer.fromJson<int>(json['commentsCount']),
      shares: serializer.fromJson<int>(json['shares']),
      isEdited: serializer.fromJson<bool>(json['isEdited']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<String>(userId),
      'content': serializer.toJson<String>(content),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'videoUrl': serializer.toJson<String?>(videoUrl),
      'location': serializer.toJson<String?>(location),
      'likes': serializer.toJson<int>(likes),
      'commentsCount': serializer.toJson<int>(commentsCount),
      'shares': serializer.toJson<int>(shares),
      'isEdited': serializer.toJson<bool>(isEdited),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Post copyWith(
          {int? id,
          String? userId,
          String? content,
          Value<String?> imageUrl = const Value.absent(),
          Value<String?> videoUrl = const Value.absent(),
          Value<String?> location = const Value.absent(),
          int? likes,
          int? commentsCount,
          int? shares,
          bool? isEdited,
          DateTime? createdAt}) =>
      Post(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        content: content ?? this.content,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        videoUrl: videoUrl.present ? videoUrl.value : this.videoUrl,
        location: location.present ? location.value : this.location,
        likes: likes ?? this.likes,
        commentsCount: commentsCount ?? this.commentsCount,
        shares: shares ?? this.shares,
        isEdited: isEdited ?? this.isEdited,
        createdAt: createdAt ?? this.createdAt,
      );
  Post copyWithCompanion(PostsCompanion data) {
    return Post(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      content: data.content.present ? data.content.value : this.content,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      videoUrl: data.videoUrl.present ? data.videoUrl.value : this.videoUrl,
      location: data.location.present ? data.location.value : this.location,
      likes: data.likes.present ? data.likes.value : this.likes,
      commentsCount: data.commentsCount.present
          ? data.commentsCount.value
          : this.commentsCount,
      shares: data.shares.present ? data.shares.value : this.shares,
      isEdited: data.isEdited.present ? data.isEdited.value : this.isEdited,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Post(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('content: $content, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('location: $location, ')
          ..write('likes: $likes, ')
          ..write('commentsCount: $commentsCount, ')
          ..write('shares: $shares, ')
          ..write('isEdited: $isEdited, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, content, imageUrl, videoUrl,
      location, likes, commentsCount, shares, isEdited, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Post &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.content == this.content &&
          other.imageUrl == this.imageUrl &&
          other.videoUrl == this.videoUrl &&
          other.location == this.location &&
          other.likes == this.likes &&
          other.commentsCount == this.commentsCount &&
          other.shares == this.shares &&
          other.isEdited == this.isEdited &&
          other.createdAt == this.createdAt);
}

class PostsCompanion extends UpdateCompanion<Post> {
  final Value<int> id;
  final Value<String> userId;
  final Value<String> content;
  final Value<String?> imageUrl;
  final Value<String?> videoUrl;
  final Value<String?> location;
  final Value<int> likes;
  final Value<int> commentsCount;
  final Value<int> shares;
  final Value<bool> isEdited;
  final Value<DateTime> createdAt;
  const PostsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.content = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.videoUrl = const Value.absent(),
    this.location = const Value.absent(),
    this.likes = const Value.absent(),
    this.commentsCount = const Value.absent(),
    this.shares = const Value.absent(),
    this.isEdited = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PostsCompanion.insert({
    this.id = const Value.absent(),
    required String userId,
    required String content,
    this.imageUrl = const Value.absent(),
    this.videoUrl = const Value.absent(),
    this.location = const Value.absent(),
    this.likes = const Value.absent(),
    this.commentsCount = const Value.absent(),
    this.shares = const Value.absent(),
    this.isEdited = const Value.absent(),
    required DateTime createdAt,
  })  : userId = Value(userId),
        content = Value(content),
        createdAt = Value(createdAt);
  static Insertable<Post> custom({
    Expression<int>? id,
    Expression<String>? userId,
    Expression<String>? content,
    Expression<String>? imageUrl,
    Expression<String>? videoUrl,
    Expression<String>? location,
    Expression<int>? likes,
    Expression<int>? commentsCount,
    Expression<int>? shares,
    Expression<bool>? isEdited,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (content != null) 'content': content,
      if (imageUrl != null) 'image_url': imageUrl,
      if (videoUrl != null) 'video_url': videoUrl,
      if (location != null) 'location': location,
      if (likes != null) 'likes': likes,
      if (commentsCount != null) 'comments_count': commentsCount,
      if (shares != null) 'shares': shares,
      if (isEdited != null) 'is_edited': isEdited,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PostsCompanion copyWith(
      {Value<int>? id,
      Value<String>? userId,
      Value<String>? content,
      Value<String?>? imageUrl,
      Value<String?>? videoUrl,
      Value<String?>? location,
      Value<int>? likes,
      Value<int>? commentsCount,
      Value<int>? shares,
      Value<bool>? isEdited,
      Value<DateTime>? createdAt}) {
    return PostsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      location: location ?? this.location,
      likes: likes ?? this.likes,
      commentsCount: commentsCount ?? this.commentsCount,
      shares: shares ?? this.shares,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (videoUrl.present) {
      map['video_url'] = Variable<String>(videoUrl.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (likes.present) {
      map['likes'] = Variable<int>(likes.value);
    }
    if (commentsCount.present) {
      map['comments_count'] = Variable<int>(commentsCount.value);
    }
    if (shares.present) {
      map['shares'] = Variable<int>(shares.value);
    }
    if (isEdited.present) {
      map['is_edited'] = Variable<bool>(isEdited.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PostsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('content: $content, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('location: $location, ')
          ..write('likes: $likes, ')
          ..write('commentsCount: $commentsCount, ')
          ..write('shares: $shares, ')
          ..write('isEdited: $isEdited, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CommentsTable extends Comments with TableInfo<$CommentsTable, Comment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CommentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _postIdMeta = const VerificationMeta('postId');
  @override
  late final GeneratedColumn<String> postId = GeneratedColumn<String>(
      'post_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _likesMeta = const VerificationMeta('likes');
  @override
  late final GeneratedColumn<int> likes = GeneratedColumn<int>(
      'likes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isEditedMeta =
      const VerificationMeta('isEdited');
  @override
  late final GeneratedColumn<bool> isEdited = GeneratedColumn<bool>(
      'is_edited', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_edited" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, postId, userId, content, likes, isEdited, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'comments';
  @override
  VerificationContext validateIntegrity(Insertable<Comment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('post_id')) {
      context.handle(_postIdMeta,
          postId.isAcceptableOrUnknown(data['post_id']!, _postIdMeta));
    } else if (isInserting) {
      context.missing(_postIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('likes')) {
      context.handle(
          _likesMeta, likes.isAcceptableOrUnknown(data['likes']!, _likesMeta));
    }
    if (data.containsKey('is_edited')) {
      context.handle(_isEditedMeta,
          isEdited.isAcceptableOrUnknown(data['is_edited']!, _isEditedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Comment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Comment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      postId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}post_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      likes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}likes'])!,
      isEdited: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_edited'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $CommentsTable createAlias(String alias) {
    return $CommentsTable(attachedDatabase, alias);
  }
}

class Comment extends DataClass implements Insertable<Comment> {
  final int id;
  final String postId;
  final String userId;
  final String content;
  final int likes;
  final bool isEdited;
  final DateTime createdAt;
  const Comment(
      {required this.id,
      required this.postId,
      required this.userId,
      required this.content,
      required this.likes,
      required this.isEdited,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['post_id'] = Variable<String>(postId);
    map['user_id'] = Variable<String>(userId);
    map['content'] = Variable<String>(content);
    map['likes'] = Variable<int>(likes);
    map['is_edited'] = Variable<bool>(isEdited);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CommentsCompanion toCompanion(bool nullToAbsent) {
    return CommentsCompanion(
      id: Value(id),
      postId: Value(postId),
      userId: Value(userId),
      content: Value(content),
      likes: Value(likes),
      isEdited: Value(isEdited),
      createdAt: Value(createdAt),
    );
  }

  factory Comment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Comment(
      id: serializer.fromJson<int>(json['id']),
      postId: serializer.fromJson<String>(json['postId']),
      userId: serializer.fromJson<String>(json['userId']),
      content: serializer.fromJson<String>(json['content']),
      likes: serializer.fromJson<int>(json['likes']),
      isEdited: serializer.fromJson<bool>(json['isEdited']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'postId': serializer.toJson<String>(postId),
      'userId': serializer.toJson<String>(userId),
      'content': serializer.toJson<String>(content),
      'likes': serializer.toJson<int>(likes),
      'isEdited': serializer.toJson<bool>(isEdited),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Comment copyWith(
          {int? id,
          String? postId,
          String? userId,
          String? content,
          int? likes,
          bool? isEdited,
          DateTime? createdAt}) =>
      Comment(
        id: id ?? this.id,
        postId: postId ?? this.postId,
        userId: userId ?? this.userId,
        content: content ?? this.content,
        likes: likes ?? this.likes,
        isEdited: isEdited ?? this.isEdited,
        createdAt: createdAt ?? this.createdAt,
      );
  Comment copyWithCompanion(CommentsCompanion data) {
    return Comment(
      id: data.id.present ? data.id.value : this.id,
      postId: data.postId.present ? data.postId.value : this.postId,
      userId: data.userId.present ? data.userId.value : this.userId,
      content: data.content.present ? data.content.value : this.content,
      likes: data.likes.present ? data.likes.value : this.likes,
      isEdited: data.isEdited.present ? data.isEdited.value : this.isEdited,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Comment(')
          ..write('id: $id, ')
          ..write('postId: $postId, ')
          ..write('userId: $userId, ')
          ..write('content: $content, ')
          ..write('likes: $likes, ')
          ..write('isEdited: $isEdited, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, postId, userId, content, likes, isEdited, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Comment &&
          other.id == this.id &&
          other.postId == this.postId &&
          other.userId == this.userId &&
          other.content == this.content &&
          other.likes == this.likes &&
          other.isEdited == this.isEdited &&
          other.createdAt == this.createdAt);
}

class CommentsCompanion extends UpdateCompanion<Comment> {
  final Value<int> id;
  final Value<String> postId;
  final Value<String> userId;
  final Value<String> content;
  final Value<int> likes;
  final Value<bool> isEdited;
  final Value<DateTime> createdAt;
  const CommentsCompanion({
    this.id = const Value.absent(),
    this.postId = const Value.absent(),
    this.userId = const Value.absent(),
    this.content = const Value.absent(),
    this.likes = const Value.absent(),
    this.isEdited = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CommentsCompanion.insert({
    this.id = const Value.absent(),
    required String postId,
    required String userId,
    required String content,
    this.likes = const Value.absent(),
    this.isEdited = const Value.absent(),
    required DateTime createdAt,
  })  : postId = Value(postId),
        userId = Value(userId),
        content = Value(content),
        createdAt = Value(createdAt);
  static Insertable<Comment> custom({
    Expression<int>? id,
    Expression<String>? postId,
    Expression<String>? userId,
    Expression<String>? content,
    Expression<int>? likes,
    Expression<bool>? isEdited,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (postId != null) 'post_id': postId,
      if (userId != null) 'user_id': userId,
      if (content != null) 'content': content,
      if (likes != null) 'likes': likes,
      if (isEdited != null) 'is_edited': isEdited,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CommentsCompanion copyWith(
      {Value<int>? id,
      Value<String>? postId,
      Value<String>? userId,
      Value<String>? content,
      Value<int>? likes,
      Value<bool>? isEdited,
      Value<DateTime>? createdAt}) {
    return CommentsCompanion(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      likes: likes ?? this.likes,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (postId.present) {
      map['post_id'] = Variable<String>(postId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (likes.present) {
      map['likes'] = Variable<int>(likes.value);
    }
    if (isEdited.present) {
      map['is_edited'] = Variable<bool>(isEdited.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CommentsCompanion(')
          ..write('id: $id, ')
          ..write('postId: $postId, ')
          ..write('userId: $userId, ')
          ..write('content: $content, ')
          ..write('likes: $likes, ')
          ..write('isEdited: $isEdited, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $NotificationsTable extends Notifications
    with TableInfo<$NotificationsTable, Notification> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _referenceIdMeta =
      const VerificationMeta('referenceId');
  @override
  late final GeneratedColumn<String> referenceId = GeneratedColumn<String>(
      'reference_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
      'is_read', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_read" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, userId, type, content, referenceId, isRead, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notifications';
  @override
  VerificationContext validateIntegrity(Insertable<Notification> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('reference_id')) {
      context.handle(
          _referenceIdMeta,
          referenceId.isAcceptableOrUnknown(
              data['reference_id']!, _referenceIdMeta));
    }
    if (data.containsKey('is_read')) {
      context.handle(_isReadMeta,
          isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Notification map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Notification(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      referenceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reference_id']),
      isRead: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_read'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $NotificationsTable createAlias(String alias) {
    return $NotificationsTable(attachedDatabase, alias);
  }
}

class Notification extends DataClass implements Insertable<Notification> {
  final int id;
  final String userId;
  final String type;
  final String content;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;
  const Notification(
      {required this.id,
      required this.userId,
      required this.type,
      required this.content,
      this.referenceId,
      required this.isRead,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<String>(userId);
    map['type'] = Variable<String>(type);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || referenceId != null) {
      map['reference_id'] = Variable<String>(referenceId);
    }
    map['is_read'] = Variable<bool>(isRead);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  NotificationsCompanion toCompanion(bool nullToAbsent) {
    return NotificationsCompanion(
      id: Value(id),
      userId: Value(userId),
      type: Value(type),
      content: Value(content),
      referenceId: referenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceId),
      isRead: Value(isRead),
      createdAt: Value(createdAt),
    );
  }

  factory Notification.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Notification(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      type: serializer.fromJson<String>(json['type']),
      content: serializer.fromJson<String>(json['content']),
      referenceId: serializer.fromJson<String?>(json['referenceId']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<String>(userId),
      'type': serializer.toJson<String>(type),
      'content': serializer.toJson<String>(content),
      'referenceId': serializer.toJson<String?>(referenceId),
      'isRead': serializer.toJson<bool>(isRead),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Notification copyWith(
          {int? id,
          String? userId,
          String? type,
          String? content,
          Value<String?> referenceId = const Value.absent(),
          bool? isRead,
          DateTime? createdAt}) =>
      Notification(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        type: type ?? this.type,
        content: content ?? this.content,
        referenceId: referenceId.present ? referenceId.value : this.referenceId,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt ?? this.createdAt,
      );
  Notification copyWithCompanion(NotificationsCompanion data) {
    return Notification(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      type: data.type.present ? data.type.value : this.type,
      content: data.content.present ? data.content.value : this.content,
      referenceId:
          data.referenceId.present ? data.referenceId.value : this.referenceId,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Notification(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('content: $content, ')
          ..write('referenceId: $referenceId, ')
          ..write('isRead: $isRead, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, type, content, referenceId, isRead, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Notification &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.type == this.type &&
          other.content == this.content &&
          other.referenceId == this.referenceId &&
          other.isRead == this.isRead &&
          other.createdAt == this.createdAt);
}

class NotificationsCompanion extends UpdateCompanion<Notification> {
  final Value<int> id;
  final Value<String> userId;
  final Value<String> type;
  final Value<String> content;
  final Value<String?> referenceId;
  final Value<bool> isRead;
  final Value<DateTime> createdAt;
  const NotificationsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.type = const Value.absent(),
    this.content = const Value.absent(),
    this.referenceId = const Value.absent(),
    this.isRead = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  NotificationsCompanion.insert({
    this.id = const Value.absent(),
    required String userId,
    required String type,
    required String content,
    this.referenceId = const Value.absent(),
    this.isRead = const Value.absent(),
    required DateTime createdAt,
  })  : userId = Value(userId),
        type = Value(type),
        content = Value(content),
        createdAt = Value(createdAt);
  static Insertable<Notification> custom({
    Expression<int>? id,
    Expression<String>? userId,
    Expression<String>? type,
    Expression<String>? content,
    Expression<String>? referenceId,
    Expression<bool>? isRead,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (type != null) 'type': type,
      if (content != null) 'content': content,
      if (referenceId != null) 'reference_id': referenceId,
      if (isRead != null) 'is_read': isRead,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  NotificationsCompanion copyWith(
      {Value<int>? id,
      Value<String>? userId,
      Value<String>? type,
      Value<String>? content,
      Value<String?>? referenceId,
      Value<bool>? isRead,
      Value<DateTime>? createdAt}) {
    return NotificationsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      content: content ?? this.content,
      referenceId: referenceId ?? this.referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (referenceId.present) {
      map['reference_id'] = Variable<String>(referenceId.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('content: $content, ')
          ..write('referenceId: $referenceId, ')
          ..write('isRead: $isRead, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CacheTable extends Cache with TableInfo<$CacheTable, CacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastAccessedMeta =
      const VerificationMeta('lastAccessed');
  @override
  late final GeneratedColumn<DateTime> lastAccessed = GeneratedColumn<DateTime>(
      'last_accessed', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _expiresAtMeta =
      const VerificationMeta('expiresAt');
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
      'expires_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [key, value, lastAccessed, expiresAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache';
  @override
  VerificationContext validateIntegrity(Insertable<CacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('last_accessed')) {
      context.handle(
          _lastAccessedMeta,
          lastAccessed.isAcceptableOrUnknown(
              data['last_accessed']!, _lastAccessedMeta));
    } else if (isInserting) {
      context.missing(_lastAccessedMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(_expiresAtMeta,
          expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      lastAccessed: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_accessed'])!,
      expiresAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expires_at']),
    );
  }

  @override
  $CacheTable createAlias(String alias) {
    return $CacheTable(attachedDatabase, alias);
  }
}

class CacheData extends DataClass implements Insertable<CacheData> {
  final String key;
  final String value;
  final DateTime lastAccessed;
  final DateTime? expiresAt;
  const CacheData(
      {required this.key,
      required this.value,
      required this.lastAccessed,
      this.expiresAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['last_accessed'] = Variable<DateTime>(lastAccessed);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    return map;
  }

  CacheCompanion toCompanion(bool nullToAbsent) {
    return CacheCompanion(
      key: Value(key),
      value: Value(value),
      lastAccessed: Value(lastAccessed),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
    );
  }

  factory CacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      lastAccessed: serializer.fromJson<DateTime>(json['lastAccessed']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'lastAccessed': serializer.toJson<DateTime>(lastAccessed),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
    };
  }

  CacheData copyWith(
          {String? key,
          String? value,
          DateTime? lastAccessed,
          Value<DateTime?> expiresAt = const Value.absent()}) =>
      CacheData(
        key: key ?? this.key,
        value: value ?? this.value,
        lastAccessed: lastAccessed ?? this.lastAccessed,
        expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
      );
  CacheData copyWithCompanion(CacheCompanion data) {
    return CacheData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      lastAccessed: data.lastAccessed.present
          ? data.lastAccessed.value
          : this.lastAccessed,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheData(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('lastAccessed: $lastAccessed, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, lastAccessed, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheData &&
          other.key == this.key &&
          other.value == this.value &&
          other.lastAccessed == this.lastAccessed &&
          other.expiresAt == this.expiresAt);
}

class CacheCompanion extends UpdateCompanion<CacheData> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> lastAccessed;
  final Value<DateTime?> expiresAt;
  final Value<int> rowid;
  const CacheCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.lastAccessed = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheCompanion.insert({
    required String key,
    required String value,
    required DateTime lastAccessed,
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value),
        lastAccessed = Value(lastAccessed);
  static Insertable<CacheData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? lastAccessed,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (lastAccessed != null) 'last_accessed': lastAccessed,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheCompanion copyWith(
      {Value<String>? key,
      Value<String>? value,
      Value<DateTime>? lastAccessed,
      Value<DateTime?>? expiresAt,
      Value<int>? rowid}) {
    return CacheCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (lastAccessed.present) {
      map['last_accessed'] = Variable<DateTime>(lastAccessed.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('lastAccessed: $lastAccessed, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnalyticsTable extends Analytics
    with TableInfo<$AnalyticsTable, Analytic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnalyticsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _eventMeta = const VerificationMeta('event');
  @override
  late final GeneratedColumn<String> event = GeneratedColumn<String>(
      'event', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
      'data', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, event, data, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'analytics';
  @override
  VerificationContext validateIntegrity(Insertable<Analytic> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event')) {
      context.handle(
          _eventMeta, event.isAcceptableOrUnknown(data['event']!, _eventMeta));
    } else if (isInserting) {
      context.missing(_eventMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
          _dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Analytic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Analytic(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      event: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event'])!,
      data: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $AnalyticsTable createAlias(String alias) {
    return $AnalyticsTable(attachedDatabase, alias);
  }
}

class Analytic extends DataClass implements Insertable<Analytic> {
  final int id;
  final String event;
  final String? data;
  final DateTime timestamp;
  const Analytic(
      {required this.id,
      required this.event,
      this.data,
      required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['event'] = Variable<String>(event);
    if (!nullToAbsent || data != null) {
      map['data'] = Variable<String>(data);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  AnalyticsCompanion toCompanion(bool nullToAbsent) {
    return AnalyticsCompanion(
      id: Value(id),
      event: Value(event),
      data: data == null && nullToAbsent ? const Value.absent() : Value(data),
      timestamp: Value(timestamp),
    );
  }

  factory Analytic.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Analytic(
      id: serializer.fromJson<int>(json['id']),
      event: serializer.fromJson<String>(json['event']),
      data: serializer.fromJson<String?>(json['data']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'event': serializer.toJson<String>(event),
      'data': serializer.toJson<String?>(data),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  Analytic copyWith(
          {int? id,
          String? event,
          Value<String?> data = const Value.absent(),
          DateTime? timestamp}) =>
      Analytic(
        id: id ?? this.id,
        event: event ?? this.event,
        data: data.present ? data.value : this.data,
        timestamp: timestamp ?? this.timestamp,
      );
  Analytic copyWithCompanion(AnalyticsCompanion data) {
    return Analytic(
      id: data.id.present ? data.id.value : this.id,
      event: data.event.present ? data.event.value : this.event,
      data: data.data.present ? data.data.value : this.data,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Analytic(')
          ..write('id: $id, ')
          ..write('event: $event, ')
          ..write('data: $data, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, event, data, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Analytic &&
          other.id == this.id &&
          other.event == this.event &&
          other.data == this.data &&
          other.timestamp == this.timestamp);
}

class AnalyticsCompanion extends UpdateCompanion<Analytic> {
  final Value<int> id;
  final Value<String> event;
  final Value<String?> data;
  final Value<DateTime> timestamp;
  const AnalyticsCompanion({
    this.id = const Value.absent(),
    this.event = const Value.absent(),
    this.data = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  AnalyticsCompanion.insert({
    this.id = const Value.absent(),
    required String event,
    this.data = const Value.absent(),
    required DateTime timestamp,
  })  : event = Value(event),
        timestamp = Value(timestamp);
  static Insertable<Analytic> custom({
    Expression<int>? id,
    Expression<String>? event,
    Expression<String>? data,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (event != null) 'event': event,
      if (data != null) 'data': data,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  AnalyticsCompanion copyWith(
      {Value<int>? id,
      Value<String>? event,
      Value<String?>? data,
      Value<DateTime>? timestamp}) {
    return AnalyticsCompanion(
      id: id ?? this.id,
      event: event ?? this.event,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (event.present) {
      map['event'] = Variable<String>(event.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnalyticsCompanion(')
          ..write('id: $id, ')
          ..write('event: $event, ')
          ..write('data: $data, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $AppMetadataTable extends AppMetadata
    with TableInfo<$AppMetadataTable, AppMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_metadata';
  @override
  VerificationContext validateIntegrity(Insertable<AppMetadataData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetadataData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AppMetadataTable createAlias(String alias) {
    return $AppMetadataTable(attachedDatabase, alias);
  }
}

class AppMetadataData extends DataClass implements Insertable<AppMetadataData> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const AppMetadataData(
      {required this.key, required this.value, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppMetadataCompanion toCompanion(bool nullToAbsent) {
    return AppMetadataCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppMetadataData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetadataData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppMetadataData copyWith({String? key, String? value, DateTime? updatedAt}) =>
      AppMetadataData(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppMetadataData copyWithCompanion(AppMetadataCompanion data) {
    return AppMetadataData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataData(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppMetadataData &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppMetadataCompanion extends UpdateCompanion<AppMetadataData> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppMetadataCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value),
        updatedAt = Value(updatedAt);
  static Insertable<AppMetadataData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppMetadataCompanion copyWith(
      {Value<String>? key,
      Value<String>? value,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return AppMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedPostsTable extends CachedPosts
    with TableInfo<$CachedPostsTable, CachedPost> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedPostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _firestoreIdMeta =
      const VerificationMeta('firestoreId');
  @override
  late final GeneratedColumn<String> firestoreId = GeneratedColumn<String>(
      'firestore_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
      'data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastAccessedMeta =
      const VerificationMeta('lastAccessed');
  @override
  late final GeneratedColumn<DateTime> lastAccessed = GeneratedColumn<DateTime>(
      'last_accessed', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [firestoreId, data, cachedAt, lastAccessed];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_posts';
  @override
  VerificationContext validateIntegrity(Insertable<CachedPost> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('firestore_id')) {
      context.handle(
          _firestoreIdMeta,
          firestoreId.isAcceptableOrUnknown(
              data['firestore_id']!, _firestoreIdMeta));
    } else if (isInserting) {
      context.missing(_firestoreIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
          _dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('last_accessed')) {
      context.handle(
          _lastAccessedMeta,
          lastAccessed.isAcceptableOrUnknown(
              data['last_accessed']!, _lastAccessedMeta));
    } else if (isInserting) {
      context.missing(_lastAccessedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {firestoreId};
  @override
  CachedPost map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedPost(
      firestoreId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}firestore_id'])!,
      data: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
      lastAccessed: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_accessed'])!,
    );
  }

  @override
  $CachedPostsTable createAlias(String alias) {
    return $CachedPostsTable(attachedDatabase, alias);
  }
}

class CachedPost extends DataClass implements Insertable<CachedPost> {
  final String firestoreId;
  final String data;
  final DateTime cachedAt;
  final DateTime lastAccessed;
  const CachedPost(
      {required this.firestoreId,
      required this.data,
      required this.cachedAt,
      required this.lastAccessed});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['firestore_id'] = Variable<String>(firestoreId);
    map['data'] = Variable<String>(data);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    map['last_accessed'] = Variable<DateTime>(lastAccessed);
    return map;
  }

  CachedPostsCompanion toCompanion(bool nullToAbsent) {
    return CachedPostsCompanion(
      firestoreId: Value(firestoreId),
      data: Value(data),
      cachedAt: Value(cachedAt),
      lastAccessed: Value(lastAccessed),
    );
  }

  factory CachedPost.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedPost(
      firestoreId: serializer.fromJson<String>(json['firestoreId']),
      data: serializer.fromJson<String>(json['data']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
      lastAccessed: serializer.fromJson<DateTime>(json['lastAccessed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'firestoreId': serializer.toJson<String>(firestoreId),
      'data': serializer.toJson<String>(data),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
      'lastAccessed': serializer.toJson<DateTime>(lastAccessed),
    };
  }

  CachedPost copyWith(
          {String? firestoreId,
          String? data,
          DateTime? cachedAt,
          DateTime? lastAccessed}) =>
      CachedPost(
        firestoreId: firestoreId ?? this.firestoreId,
        data: data ?? this.data,
        cachedAt: cachedAt ?? this.cachedAt,
        lastAccessed: lastAccessed ?? this.lastAccessed,
      );
  CachedPost copyWithCompanion(CachedPostsCompanion data) {
    return CachedPost(
      firestoreId:
          data.firestoreId.present ? data.firestoreId.value : this.firestoreId,
      data: data.data.present ? data.data.value : this.data,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      lastAccessed: data.lastAccessed.present
          ? data.lastAccessed.value
          : this.lastAccessed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedPost(')
          ..write('firestoreId: $firestoreId, ')
          ..write('data: $data, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('lastAccessed: $lastAccessed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(firestoreId, data, cachedAt, lastAccessed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedPost &&
          other.firestoreId == this.firestoreId &&
          other.data == this.data &&
          other.cachedAt == this.cachedAt &&
          other.lastAccessed == this.lastAccessed);
}

class CachedPostsCompanion extends UpdateCompanion<CachedPost> {
  final Value<String> firestoreId;
  final Value<String> data;
  final Value<DateTime> cachedAt;
  final Value<DateTime> lastAccessed;
  final Value<int> rowid;
  const CachedPostsCompanion({
    this.firestoreId = const Value.absent(),
    this.data = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.lastAccessed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedPostsCompanion.insert({
    required String firestoreId,
    required String data,
    required DateTime cachedAt,
    required DateTime lastAccessed,
    this.rowid = const Value.absent(),
  })  : firestoreId = Value(firestoreId),
        data = Value(data),
        cachedAt = Value(cachedAt),
        lastAccessed = Value(lastAccessed);
  static Insertable<CachedPost> custom({
    Expression<String>? firestoreId,
    Expression<String>? data,
    Expression<DateTime>? cachedAt,
    Expression<DateTime>? lastAccessed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (firestoreId != null) 'firestore_id': firestoreId,
      if (data != null) 'data': data,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (lastAccessed != null) 'last_accessed': lastAccessed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedPostsCompanion copyWith(
      {Value<String>? firestoreId,
      Value<String>? data,
      Value<DateTime>? cachedAt,
      Value<DateTime>? lastAccessed,
      Value<int>? rowid}) {
    return CachedPostsCompanion(
      firestoreId: firestoreId ?? this.firestoreId,
      data: data ?? this.data,
      cachedAt: cachedAt ?? this.cachedAt,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (firestoreId.present) {
      map['firestore_id'] = Variable<String>(firestoreId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (lastAccessed.present) {
      map['last_accessed'] = Variable<DateTime>(lastAccessed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedPostsCompanion(')
          ..write('firestoreId: $firestoreId, ')
          ..write('data: $data, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('lastAccessed: $lastAccessed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppUsersTable appUsers = $AppUsersTable(this);
  late final $PostsTable posts = $PostsTable(this);
  late final $CommentsTable comments = $CommentsTable(this);
  late final $NotificationsTable notifications = $NotificationsTable(this);
  late final $CacheTable cache = $CacheTable(this);
  late final $AnalyticsTable analytics = $AnalyticsTable(this);
  late final $AppMetadataTable appMetadata = $AppMetadataTable(this);
  late final $CachedPostsTable cachedPosts = $CachedPostsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        appUsers,
        posts,
        comments,
        notifications,
        cache,
        analytics,
        appMetadata,
        cachedPosts
      ];
}

typedef $$AppUsersTableCreateCompanionBuilder = AppUsersCompanion Function({
  required String id,
  required String username,
  required String email,
  Value<String?> profileImage,
  Value<bool> isVerified,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$AppUsersTableUpdateCompanionBuilder = AppUsersCompanion Function({
  Value<String> id,
  Value<String> username,
  Value<String> email,
  Value<String?> profileImage,
  Value<bool> isVerified,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$AppUsersTableFilterComposer
    extends Composer<_$AppDatabase, $AppUsersTable> {
  $$AppUsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get profileImage => $composableBuilder(
      column: $table.profileImage, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isVerified => $composableBuilder(
      column: $table.isVerified, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AppUsersTableOrderingComposer
    extends Composer<_$AppDatabase, $AppUsersTable> {
  $$AppUsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get profileImage => $composableBuilder(
      column: $table.profileImage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isVerified => $composableBuilder(
      column: $table.isVerified, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AppUsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppUsersTable> {
  $$AppUsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get profileImage => $composableBuilder(
      column: $table.profileImage, builder: (column) => column);

  GeneratedColumn<bool> get isVerified => $composableBuilder(
      column: $table.isVerified, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AppUsersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppUsersTable,
    AppUser,
    $$AppUsersTableFilterComposer,
    $$AppUsersTableOrderingComposer,
    $$AppUsersTableAnnotationComposer,
    $$AppUsersTableCreateCompanionBuilder,
    $$AppUsersTableUpdateCompanionBuilder,
    (AppUser, BaseReferences<_$AppDatabase, $AppUsersTable, AppUser>),
    AppUser,
    PrefetchHooks Function()> {
  $$AppUsersTableTableManager(_$AppDatabase db, $AppUsersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppUsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppUsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppUsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> username = const Value.absent(),
            Value<String> email = const Value.absent(),
            Value<String?> profileImage = const Value.absent(),
            Value<bool> isVerified = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppUsersCompanion(
            id: id,
            username: username,
            email: email,
            profileImage: profileImage,
            isVerified: isVerified,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String username,
            required String email,
            Value<String?> profileImage = const Value.absent(),
            Value<bool> isVerified = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppUsersCompanion.insert(
            id: id,
            username: username,
            email: email,
            profileImage: profileImage,
            isVerified: isVerified,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppUsersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppUsersTable,
    AppUser,
    $$AppUsersTableFilterComposer,
    $$AppUsersTableOrderingComposer,
    $$AppUsersTableAnnotationComposer,
    $$AppUsersTableCreateCompanionBuilder,
    $$AppUsersTableUpdateCompanionBuilder,
    (AppUser, BaseReferences<_$AppDatabase, $AppUsersTable, AppUser>),
    AppUser,
    PrefetchHooks Function()>;
typedef $$PostsTableCreateCompanionBuilder = PostsCompanion Function({
  Value<int> id,
  required String userId,
  required String content,
  Value<String?> imageUrl,
  Value<String?> videoUrl,
  Value<String?> location,
  Value<int> likes,
  Value<int> commentsCount,
  Value<int> shares,
  Value<bool> isEdited,
  required DateTime createdAt,
});
typedef $$PostsTableUpdateCompanionBuilder = PostsCompanion Function({
  Value<int> id,
  Value<String> userId,
  Value<String> content,
  Value<String?> imageUrl,
  Value<String?> videoUrl,
  Value<String?> location,
  Value<int> likes,
  Value<int> commentsCount,
  Value<int> shares,
  Value<bool> isEdited,
  Value<DateTime> createdAt,
});

class $$PostsTableFilterComposer extends Composer<_$AppDatabase, $PostsTable> {
  $$PostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get videoUrl => $composableBuilder(
      column: $table.videoUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get likes => $composableBuilder(
      column: $table.likes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get commentsCount => $composableBuilder(
      column: $table.commentsCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get shares => $composableBuilder(
      column: $table.shares, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isEdited => $composableBuilder(
      column: $table.isEdited, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$PostsTableOrderingComposer
    extends Composer<_$AppDatabase, $PostsTable> {
  $$PostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get videoUrl => $composableBuilder(
      column: $table.videoUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get likes => $composableBuilder(
      column: $table.likes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get commentsCount => $composableBuilder(
      column: $table.commentsCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get shares => $composableBuilder(
      column: $table.shares, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isEdited => $composableBuilder(
      column: $table.isEdited, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$PostsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PostsTable> {
  $$PostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get videoUrl =>
      $composableBuilder(column: $table.videoUrl, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<int> get likes =>
      $composableBuilder(column: $table.likes, builder: (column) => column);

  GeneratedColumn<int> get commentsCount => $composableBuilder(
      column: $table.commentsCount, builder: (column) => column);

  GeneratedColumn<int> get shares =>
      $composableBuilder(column: $table.shares, builder: (column) => column);

  GeneratedColumn<bool> get isEdited =>
      $composableBuilder(column: $table.isEdited, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PostsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PostsTable,
    Post,
    $$PostsTableFilterComposer,
    $$PostsTableOrderingComposer,
    $$PostsTableAnnotationComposer,
    $$PostsTableCreateCompanionBuilder,
    $$PostsTableUpdateCompanionBuilder,
    (Post, BaseReferences<_$AppDatabase, $PostsTable, Post>),
    Post,
    PrefetchHooks Function()> {
  $$PostsTableTableManager(_$AppDatabase db, $PostsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String?> videoUrl = const Value.absent(),
            Value<String?> location = const Value.absent(),
            Value<int> likes = const Value.absent(),
            Value<int> commentsCount = const Value.absent(),
            Value<int> shares = const Value.absent(),
            Value<bool> isEdited = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              PostsCompanion(
            id: id,
            userId: userId,
            content: content,
            imageUrl: imageUrl,
            videoUrl: videoUrl,
            location: location,
            likes: likes,
            commentsCount: commentsCount,
            shares: shares,
            isEdited: isEdited,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String userId,
            required String content,
            Value<String?> imageUrl = const Value.absent(),
            Value<String?> videoUrl = const Value.absent(),
            Value<String?> location = const Value.absent(),
            Value<int> likes = const Value.absent(),
            Value<int> commentsCount = const Value.absent(),
            Value<int> shares = const Value.absent(),
            Value<bool> isEdited = const Value.absent(),
            required DateTime createdAt,
          }) =>
              PostsCompanion.insert(
            id: id,
            userId: userId,
            content: content,
            imageUrl: imageUrl,
            videoUrl: videoUrl,
            location: location,
            likes: likes,
            commentsCount: commentsCount,
            shares: shares,
            isEdited: isEdited,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PostsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PostsTable,
    Post,
    $$PostsTableFilterComposer,
    $$PostsTableOrderingComposer,
    $$PostsTableAnnotationComposer,
    $$PostsTableCreateCompanionBuilder,
    $$PostsTableUpdateCompanionBuilder,
    (Post, BaseReferences<_$AppDatabase, $PostsTable, Post>),
    Post,
    PrefetchHooks Function()>;
typedef $$CommentsTableCreateCompanionBuilder = CommentsCompanion Function({
  Value<int> id,
  required String postId,
  required String userId,
  required String content,
  Value<int> likes,
  Value<bool> isEdited,
  required DateTime createdAt,
});
typedef $$CommentsTableUpdateCompanionBuilder = CommentsCompanion Function({
  Value<int> id,
  Value<String> postId,
  Value<String> userId,
  Value<String> content,
  Value<int> likes,
  Value<bool> isEdited,
  Value<DateTime> createdAt,
});

class $$CommentsTableFilterComposer
    extends Composer<_$AppDatabase, $CommentsTable> {
  $$CommentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get postId => $composableBuilder(
      column: $table.postId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get likes => $composableBuilder(
      column: $table.likes, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isEdited => $composableBuilder(
      column: $table.isEdited, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$CommentsTableOrderingComposer
    extends Composer<_$AppDatabase, $CommentsTable> {
  $$CommentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get postId => $composableBuilder(
      column: $table.postId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get likes => $composableBuilder(
      column: $table.likes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isEdited => $composableBuilder(
      column: $table.isEdited, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$CommentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CommentsTable> {
  $$CommentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get postId =>
      $composableBuilder(column: $table.postId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get likes =>
      $composableBuilder(column: $table.likes, builder: (column) => column);

  GeneratedColumn<bool> get isEdited =>
      $composableBuilder(column: $table.isEdited, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CommentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CommentsTable,
    Comment,
    $$CommentsTableFilterComposer,
    $$CommentsTableOrderingComposer,
    $$CommentsTableAnnotationComposer,
    $$CommentsTableCreateCompanionBuilder,
    $$CommentsTableUpdateCompanionBuilder,
    (Comment, BaseReferences<_$AppDatabase, $CommentsTable, Comment>),
    Comment,
    PrefetchHooks Function()> {
  $$CommentsTableTableManager(_$AppDatabase db, $CommentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CommentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CommentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CommentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> postId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<int> likes = const Value.absent(),
            Value<bool> isEdited = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              CommentsCompanion(
            id: id,
            postId: postId,
            userId: userId,
            content: content,
            likes: likes,
            isEdited: isEdited,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String postId,
            required String userId,
            required String content,
            Value<int> likes = const Value.absent(),
            Value<bool> isEdited = const Value.absent(),
            required DateTime createdAt,
          }) =>
              CommentsCompanion.insert(
            id: id,
            postId: postId,
            userId: userId,
            content: content,
            likes: likes,
            isEdited: isEdited,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CommentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CommentsTable,
    Comment,
    $$CommentsTableFilterComposer,
    $$CommentsTableOrderingComposer,
    $$CommentsTableAnnotationComposer,
    $$CommentsTableCreateCompanionBuilder,
    $$CommentsTableUpdateCompanionBuilder,
    (Comment, BaseReferences<_$AppDatabase, $CommentsTable, Comment>),
    Comment,
    PrefetchHooks Function()>;
typedef $$NotificationsTableCreateCompanionBuilder = NotificationsCompanion
    Function({
  Value<int> id,
  required String userId,
  required String type,
  required String content,
  Value<String?> referenceId,
  Value<bool> isRead,
  required DateTime createdAt,
});
typedef $$NotificationsTableUpdateCompanionBuilder = NotificationsCompanion
    Function({
  Value<int> id,
  Value<String> userId,
  Value<String> type,
  Value<String> content,
  Value<String?> referenceId,
  Value<bool> isRead,
  Value<DateTime> createdAt,
});

class $$NotificationsTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationsTable> {
  $$NotificationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get referenceId => $composableBuilder(
      column: $table.referenceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$NotificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationsTable> {
  $$NotificationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get referenceId => $composableBuilder(
      column: $table.referenceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$NotificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationsTable> {
  $$NotificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get referenceId => $composableBuilder(
      column: $table.referenceId, builder: (column) => column);

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$NotificationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NotificationsTable,
    Notification,
    $$NotificationsTableFilterComposer,
    $$NotificationsTableOrderingComposer,
    $$NotificationsTableAnnotationComposer,
    $$NotificationsTableCreateCompanionBuilder,
    $$NotificationsTableUpdateCompanionBuilder,
    (
      Notification,
      BaseReferences<_$AppDatabase, $NotificationsTable, Notification>
    ),
    Notification,
    PrefetchHooks Function()> {
  $$NotificationsTableTableManager(_$AppDatabase db, $NotificationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotificationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String?> referenceId = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              NotificationsCompanion(
            id: id,
            userId: userId,
            type: type,
            content: content,
            referenceId: referenceId,
            isRead: isRead,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String userId,
            required String type,
            required String content,
            Value<String?> referenceId = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
            required DateTime createdAt,
          }) =>
              NotificationsCompanion.insert(
            id: id,
            userId: userId,
            type: type,
            content: content,
            referenceId: referenceId,
            isRead: isRead,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NotificationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NotificationsTable,
    Notification,
    $$NotificationsTableFilterComposer,
    $$NotificationsTableOrderingComposer,
    $$NotificationsTableAnnotationComposer,
    $$NotificationsTableCreateCompanionBuilder,
    $$NotificationsTableUpdateCompanionBuilder,
    (
      Notification,
      BaseReferences<_$AppDatabase, $NotificationsTable, Notification>
    ),
    Notification,
    PrefetchHooks Function()>;
typedef $$CacheTableCreateCompanionBuilder = CacheCompanion Function({
  required String key,
  required String value,
  required DateTime lastAccessed,
  Value<DateTime?> expiresAt,
  Value<int> rowid,
});
typedef $$CacheTableUpdateCompanionBuilder = CacheCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<DateTime> lastAccessed,
  Value<DateTime?> expiresAt,
  Value<int> rowid,
});

class $$CacheTableFilterComposer extends Composer<_$AppDatabase, $CacheTable> {
  $$CacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastAccessed => $composableBuilder(
      column: $table.lastAccessed, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnFilters(column));
}

class $$CacheTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheTable> {
  $$CacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastAccessed => $composableBuilder(
      column: $table.lastAccessed,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnOrderings(column));
}

class $$CacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheTable> {
  $$CacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAccessed => $composableBuilder(
      column: $table.lastAccessed, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$CacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CacheTable,
    CacheData,
    $$CacheTableFilterComposer,
    $$CacheTableOrderingComposer,
    $$CacheTableAnnotationComposer,
    $$CacheTableCreateCompanionBuilder,
    $$CacheTableUpdateCompanionBuilder,
    (CacheData, BaseReferences<_$AppDatabase, $CacheTable, CacheData>),
    CacheData,
    PrefetchHooks Function()> {
  $$CacheTableTableManager(_$AppDatabase db, $CacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<DateTime> lastAccessed = const Value.absent(),
            Value<DateTime?> expiresAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CacheCompanion(
            key: key,
            value: value,
            lastAccessed: lastAccessed,
            expiresAt: expiresAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            required DateTime lastAccessed,
            Value<DateTime?> expiresAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CacheCompanion.insert(
            key: key,
            value: value,
            lastAccessed: lastAccessed,
            expiresAt: expiresAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CacheTable,
    CacheData,
    $$CacheTableFilterComposer,
    $$CacheTableOrderingComposer,
    $$CacheTableAnnotationComposer,
    $$CacheTableCreateCompanionBuilder,
    $$CacheTableUpdateCompanionBuilder,
    (CacheData, BaseReferences<_$AppDatabase, $CacheTable, CacheData>),
    CacheData,
    PrefetchHooks Function()>;
typedef $$AnalyticsTableCreateCompanionBuilder = AnalyticsCompanion Function({
  Value<int> id,
  required String event,
  Value<String?> data,
  required DateTime timestamp,
});
typedef $$AnalyticsTableUpdateCompanionBuilder = AnalyticsCompanion Function({
  Value<int> id,
  Value<String> event,
  Value<String?> data,
  Value<DateTime> timestamp,
});

class $$AnalyticsTableFilterComposer
    extends Composer<_$AppDatabase, $AnalyticsTable> {
  $$AnalyticsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get event => $composableBuilder(
      column: $table.event, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));
}

class $$AnalyticsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnalyticsTable> {
  $$AnalyticsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get event => $composableBuilder(
      column: $table.event, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));
}

class $$AnalyticsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnalyticsTable> {
  $$AnalyticsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get event =>
      $composableBuilder(column: $table.event, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$AnalyticsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AnalyticsTable,
    Analytic,
    $$AnalyticsTableFilterComposer,
    $$AnalyticsTableOrderingComposer,
    $$AnalyticsTableAnnotationComposer,
    $$AnalyticsTableCreateCompanionBuilder,
    $$AnalyticsTableUpdateCompanionBuilder,
    (Analytic, BaseReferences<_$AppDatabase, $AnalyticsTable, Analytic>),
    Analytic,
    PrefetchHooks Function()> {
  $$AnalyticsTableTableManager(_$AppDatabase db, $AnalyticsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnalyticsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnalyticsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnalyticsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> event = const Value.absent(),
            Value<String?> data = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              AnalyticsCompanion(
            id: id,
            event: event,
            data: data,
            timestamp: timestamp,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String event,
            Value<String?> data = const Value.absent(),
            required DateTime timestamp,
          }) =>
              AnalyticsCompanion.insert(
            id: id,
            event: event,
            data: data,
            timestamp: timestamp,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AnalyticsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AnalyticsTable,
    Analytic,
    $$AnalyticsTableFilterComposer,
    $$AnalyticsTableOrderingComposer,
    $$AnalyticsTableAnnotationComposer,
    $$AnalyticsTableCreateCompanionBuilder,
    $$AnalyticsTableUpdateCompanionBuilder,
    (Analytic, BaseReferences<_$AppDatabase, $AnalyticsTable, Analytic>),
    Analytic,
    PrefetchHooks Function()>;
typedef $$AppMetadataTableCreateCompanionBuilder = AppMetadataCompanion
    Function({
  required String key,
  required String value,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$AppMetadataTableUpdateCompanionBuilder = AppMetadataCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$AppMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $AppMetadataTable> {
  $$AppMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$AppMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $AppMetadataTable> {
  $$AppMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$AppMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppMetadataTable> {
  $$AppMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppMetadataTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppMetadataTable,
    AppMetadataData,
    $$AppMetadataTableFilterComposer,
    $$AppMetadataTableOrderingComposer,
    $$AppMetadataTableAnnotationComposer,
    $$AppMetadataTableCreateCompanionBuilder,
    $$AppMetadataTableUpdateCompanionBuilder,
    (
      AppMetadataData,
      BaseReferences<_$AppDatabase, $AppMetadataTable, AppMetadataData>
    ),
    AppMetadataData,
    PrefetchHooks Function()> {
  $$AppMetadataTableTableManager(_$AppDatabase db, $AppMetadataTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppMetadataCompanion(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppMetadataCompanion.insert(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppMetadataTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppMetadataTable,
    AppMetadataData,
    $$AppMetadataTableFilterComposer,
    $$AppMetadataTableOrderingComposer,
    $$AppMetadataTableAnnotationComposer,
    $$AppMetadataTableCreateCompanionBuilder,
    $$AppMetadataTableUpdateCompanionBuilder,
    (
      AppMetadataData,
      BaseReferences<_$AppDatabase, $AppMetadataTable, AppMetadataData>
    ),
    AppMetadataData,
    PrefetchHooks Function()>;
typedef $$CachedPostsTableCreateCompanionBuilder = CachedPostsCompanion
    Function({
  required String firestoreId,
  required String data,
  required DateTime cachedAt,
  required DateTime lastAccessed,
  Value<int> rowid,
});
typedef $$CachedPostsTableUpdateCompanionBuilder = CachedPostsCompanion
    Function({
  Value<String> firestoreId,
  Value<String> data,
  Value<DateTime> cachedAt,
  Value<DateTime> lastAccessed,
  Value<int> rowid,
});

class $$CachedPostsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedPostsTable> {
  $$CachedPostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get firestoreId => $composableBuilder(
      column: $table.firestoreId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastAccessed => $composableBuilder(
      column: $table.lastAccessed, builder: (column) => ColumnFilters(column));
}

class $$CachedPostsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedPostsTable> {
  $$CachedPostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get firestoreId => $composableBuilder(
      column: $table.firestoreId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastAccessed => $composableBuilder(
      column: $table.lastAccessed,
      builder: (column) => ColumnOrderings(column));
}

class $$CachedPostsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedPostsTable> {
  $$CachedPostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get firestoreId => $composableBuilder(
      column: $table.firestoreId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAccessed => $composableBuilder(
      column: $table.lastAccessed, builder: (column) => column);
}

class $$CachedPostsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedPostsTable,
    CachedPost,
    $$CachedPostsTableFilterComposer,
    $$CachedPostsTableOrderingComposer,
    $$CachedPostsTableAnnotationComposer,
    $$CachedPostsTableCreateCompanionBuilder,
    $$CachedPostsTableUpdateCompanionBuilder,
    (CachedPost, BaseReferences<_$AppDatabase, $CachedPostsTable, CachedPost>),
    CachedPost,
    PrefetchHooks Function()> {
  $$CachedPostsTableTableManager(_$AppDatabase db, $CachedPostsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedPostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedPostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedPostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> firestoreId = const Value.absent(),
            Value<String> data = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<DateTime> lastAccessed = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedPostsCompanion(
            firestoreId: firestoreId,
            data: data,
            cachedAt: cachedAt,
            lastAccessed: lastAccessed,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String firestoreId,
            required String data,
            required DateTime cachedAt,
            required DateTime lastAccessed,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedPostsCompanion.insert(
            firestoreId: firestoreId,
            data: data,
            cachedAt: cachedAt,
            lastAccessed: lastAccessed,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedPostsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedPostsTable,
    CachedPost,
    $$CachedPostsTableFilterComposer,
    $$CachedPostsTableOrderingComposer,
    $$CachedPostsTableAnnotationComposer,
    $$CachedPostsTableCreateCompanionBuilder,
    $$CachedPostsTableUpdateCompanionBuilder,
    (CachedPost, BaseReferences<_$AppDatabase, $CachedPostsTable, CachedPost>),
    CachedPost,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppUsersTableTableManager get appUsers =>
      $$AppUsersTableTableManager(_db, _db.appUsers);
  $$PostsTableTableManager get posts =>
      $$PostsTableTableManager(_db, _db.posts);
  $$CommentsTableTableManager get comments =>
      $$CommentsTableTableManager(_db, _db.comments);
  $$NotificationsTableTableManager get notifications =>
      $$NotificationsTableTableManager(_db, _db.notifications);
  $$CacheTableTableManager get cache =>
      $$CacheTableTableManager(_db, _db.cache);
  $$AnalyticsTableTableManager get analytics =>
      $$AnalyticsTableTableManager(_db, _db.analytics);
  $$AppMetadataTableTableManager get appMetadata =>
      $$AppMetadataTableTableManager(_db, _db.appMetadata);
  $$CachedPostsTableTableManager get cachedPosts =>
      $$CachedPostsTableTableManager(_db, _db.cachedPosts);
}
