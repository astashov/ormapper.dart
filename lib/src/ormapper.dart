library ormapper.ormapper;

import 'package:collection/collection.dart';
import 'dart:async';
import 'package:dapter/dapter.dart';
import 'package:squilder/squilder.dart' as sql;
import 'package:option/option.dart';
import 'package:ormapper/ormapper.dart';
import 'package:ormapper/src/relation.dart';

abstract class ORMapper<T> implements Queriable<T> {
  final Adapter adapter;
  ORMapper(this.adapter);
  Iterable<T> modelFactory(List row);

  sql.Table get table;

  Future<Iterable<T>> execute(String sql, [Iterable<T> mapper(Iterable<Map<sql.TableField, dynamic>> rows) = null]) {
    mapper ??= modelFactory;
    return adapter.query(sql).then((rows) => rows.map(_rowFactory)).then(mapper);
  }

  Query<T> find(int id) => where(table.primaryKey.eqToObj(id));

  Query<T> where(sql.Condition condition) => new Query(this).where(condition);
  Query belongsTo(int id, ORMapper mapper, sql.TableField joinField) => new Query(this).belongsTo(id, mapper, joinField);
  Query hasMany(int id, ORMapper mapper, sql.TableField joinField) => new Query(this).hasMany(id, mapper, joinField);
  Query hasManyThrough(int id, Iterable<Relation> relations) => new Query(this).hasManyThrough(id, relations);
  Query hasAndBelongsToMany(int id, ORMapper intermediateMapper, ORMapper targetMapper, sql.TableField sourceField, sql.TableField targetField) {
    return new Query(this).hasAndBelongsToMany(id, intermediateMapper, targetMapper, sourceField, targetField);
  }
  Future<Option<T>> first([ORMapper finalMapper]) => new Query(this).first();
  Future<Iterable<T>> all([ORMapper finalMapper]) => new Query(this).all();
  Query<T> offset(int number) => new Query(this).offset(number);
  Query<T> limit(int number) => new Query(this).limit(number);
  Query<T> sortBy(sql.TableField field, [String type = "ASC"]) => new Query(this).sortBy(field, type);
  Query<T> groupBy(sql.TableField field) => new Query(this).groupBy(field);
  Query<T> having(sql.Condition condition) => new Query(this).having(condition);

  Future<int> create(Map<sql.TableField, dynamic> map) {
    var sqlString = sql.insertInto(table, map.keys).values(map.values).toSql();
    return adapter.insert(sqlString);
  }

  Future<Null> update(primaryKeyValue, Map<sql.TableField, dynamic> map) async {
    sql.Update sqlString = sql.update(this.table);
    map.forEach((field, value) {
      if (field != table.primaryKey) {
        sqlString = sqlString.setObj(field, value);
      }
    });
    sqlString = sqlString.where(table.primaryKey.eqToObj(primaryKeyValue));
    await adapter.query(sqlString.toSql());
    return null;
  }

  Map<sql.TableField, dynamic> _rowFactory(List row) {
    return new IterableZip([table.f.all, row]).fold({}, (Map<sql.TableField, dynamic> memo, List elements) {
      memo[elements[0]] = elements[1];
      return memo;
    });
  }
}
