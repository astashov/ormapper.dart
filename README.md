# ORMapper

Lightweight ORM, built on top of [Squilder](https://pub.dartlang.org/packages/squilder).
Inspired by [ScalikeJDBC](http://scalikejdbc.org/) and [Skinny ORM](http://skinny-framework.org/documentation/orm.html)

## Why

Sometimes it's just not enough to have type-safe SQL builder, it's also nice to have something, which would map
resulting rows to models and have a way to specify associations. This is what `ORMapper` for.

## Usage

Imagine you have the MySQL tables `users`, `posts` and `comments`, they look something like this:

```
users:
int id, String login

posts:
int id, int user_id, String title, String text

comments:
int id, int user_id, String text
```

First thing - since it's based on [Squilder](https://pub.dartlang.org/packages/squilder), we need to generate schema classes.
For that, create a file `bin/schema_generator.dart`, and add this code:

```dart
import 'package:sqljocky/sqljocky.dart';
import 'package:squilder/schema_generator.dart' as generator;

void main() {
  generator.generate(
      dbType: "mysql",
      host: "localhost",
      user: "root",
      password: "pass",
      port: 3306,
      database: "your_db",
      output: "dbschema.dart",
      library: "dbschema");
}
```

Then, run it as `dart bin/schema_generator.dart`. It will create the file `dbschema.dart`, with the schema classes for
the tables `posts`, `users` and `comments`.

Now, let's create the models and the mappers for them:

Models:

```dart
import 'dbschema.dart';
import 'package:squilder/squilder.dart';

// models
class User {
  final int id;
  final String login;
  User(this.id, this.login);

  factory User.fromRow(Map<TableField, dynamic> row) {
    return new User(
        row[users.f.id],
        row[users.f.login]);
  }

  Map<TableField, dynamic> toRow() {
    return {
        users.f.id: id,
        users.f.login: login};

  bool operator ==(other) =>
      other is User && id == other.id && login == other.login;

  int hashCode => id.hashCode ^ login.hashCode;
}

class Post {
  final int id;
  final int userId;
  final String title;
  final String text;
  Post(this.id, this.userId, this.title, this.text);

  factory Post.fromRow(Map<TableField, dynamic> row) {
    return new Post(
        row[posts.f.id],
        row[posts.f.userId],
        row[posts.f.title],
        row[posts.f.text]);
  }

  Map<TableField, dynamic> toRow() {
    return {
        posts.f.id: id,
        posts.f.userId: userId,
        posts.f.title: title,
        posts.f.text: text};
  }

  bool operator ==(other) =>
      other is Post && id == other.id && userId == other.userId
          && title == other.title && text == other.text;

  int hashCode => id.hashCode ^ userId.hashCode ^ title.hashCode ^ text.hashCode;
}

class Comment {
  final int id;
  final int userId;
  final String text;
  Comment(this.id, this.userId, this.text);

  factory Comment.fromRow(Map<TableField, dynamic> row) {
    return new Comment(
        row[comments.f.id],
        row[comments.f.userId],
        row[comments.f.text]);
  }

  Map<TableField, dynamic> toRow() {
    return {
        comments.f.id: id,
        comments.f.userId: userId,
        comments.f.text: text};
  }

  bool operator ==(other) =>
      other is Comment && id == other.id && userId == other.userId
          && text == other.text;

  int hashCode => id.hashCode ^ userId.hashCode ^ text.hashCode;
}
```

and finally - mappers:

```dart
// mappers

class UserMapper extends ORMapper<User> {
  UsersTable get table => users;
  UserMapper(Adapter adapter) : super(adapter);
  Iterable<User> modelFactory(Iterable<Map<TableField, dynamic>> rows) =>
      rows.map((Map<TableField, dynamic> row) => new User.fromRow(row)).toSet();
}
final UserMapper userMapper = new UserMapper(adapter);

class PostMapper extends ORMapper<Post> {
  PostsTable get table => posts;
  PostMapper(Adapter adapter) : super(adapter);
  Iterable<Post> modelFactory(Iterable<Map<TableField, dynamic>> rows) =>
      rows.map((Map<TableField, dynamic> row) => new Post.fromRow(row)).toSet();
}
final PostMapper postMapper = new PostMapper(adapter);

class CommentMapper extends ORMapper<Comment> {
  CommentsTable get table => comments;
  CommentMapper(Adapter adapter) : super(adapter);
  Iterable<Comment> modelFactory(Iterable<Map<TableField, dynamic>> rows) =>
      rows.map((Map<TableField, dynamic> row) => new Comment.fromRow(row)).toSet();
}
final CommentMapper commentMapper = new CommentMapper(adapter);
```

For every mapper, you have to define 3 things: `table` getter, which returns the table from the `dbschema.dart` generated
file, a constructor, and the `modelFactory` method, which converts a row to an actual model.

Now, you can do things like this:

```dart
Option<User> user = await userMapper.find(1).first();
Iterable<User> startsWithBUsers = await userMapper.where(userMapper.table.f.name.like("B%")).all();
Iterable<Post> postsWithGoodComments = await postMapper
    .addJoin(commentMapper, commentMapper.table.f.postId.eqToField(postMapper.table.f.id))
    .where(commentMapper.table.f.text.like("%great%")).all();
```

It's very common when you need to specify associations, like find all the comments of the post, or user of the comment.
So, you can specify `hasMany`, `belongsTo`, `hasAndBelongsToMany` and `hasManyThrough` associations.

Let's add them e.g. to our Post mapper:

```dart
class PostMapper extends ORMapper<Post> {
  // ... old code here

  Query<Comment> comments(int postId) =>
      hasMany(postId, commentMapper, commentMapper.table.f.postId);

  Query<User> user(int postId) =>
      belongsTo(postId, userMapper, table.f.userId);
}
```

Now you can do:

```dart
Iterable<Comment> comments = await postMapper.comments(1).all();
Option<User> user = await postMapper.user(1).first();
```

Or even something more complicated, e.g. association for all the comments of posts of a specific user, would be:

```dart
class UserMapper extends ORMapper<User> {
  // ..old code

  Query<Comment> commentsOfPosts(userId) =>
      hasManyThrough(userId, [
          new Relation(postMapper, postMapper.table.f.userId),
          new Relation(commentMapper, commentMapper.table.f.postId)]);
}
```

```dart
Iterable<Comment> comments = await userMapper.commentsOfPosts(1).all();
```

You can save and update the records as well:

```dart
Comment comment = new Comment(1, 1, "blah");
await commentMapper.create(comment.toRow());

Post post = (await postMapper.find(1)).get();
Post newPost = new Post(post.id, post.userId, "new title", post.text);
await postMapper.update(newPost.id, newPost);
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/astashov/ormapper.dart
