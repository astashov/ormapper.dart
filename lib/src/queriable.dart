library ormapper.queriable;

import 'dart:async';
import 'package:option/option.dart';
import 'package:squilder/squilder.dart';
import 'package:ormapper/ormapper.dart';
import 'package:ormapper/src/relation.dart';

abstract class Queriable<T> {
  Future<Option<T>> first();
  Future<Iterable<T>> all();
  Query belongsTo(int id, ORMapper joinMapper, TableField joinField);
  Query hasMany(int id, ORMapper joinMapper, TableField joinField);
  Query hasManyThrough(int id, Iterable<Relation> relations);
  Query hasAndBelongsToMany(int id, ORMapper intermediateMapper, ORMapper targetMapper, TableField sourceField, TableField targetField);
  Query<T> where(Condition condition);
  Query<T> having(Condition condition);
  Query<T> groupBy(TableField field);
  Query<T> sortBy(TableField field, [String type = "ASC"]);
  Query<T> limit(int number);
  Query<T> offset(int number);
}
