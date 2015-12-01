library ormapper.query;

import 'package:ormapper/ormapper.dart';
import 'package:squilder/squilder.dart';
import 'dart:async';
import 'package:option/option.dart';
import 'package:ormapper/src/join.dart';
import 'package:ormapper/src/relation.dart';

class Query<T> implements Queriable<T> {
  final Iterable<Join> _joins;
  final Condition _whereCondition;
  final Condition _havingCondition;
  final TableField _groupByField;
  final OrderPair _sortByPair;
  final int _offsetValue;
  final int _limitValue;

  final ORMapper<T> _mapper;
  final ORMapper _finalMapper;

  Query(this._mapper, {
      Iterable<Join> joins,
      Condition whereCondition,
      Condition havingCondition,
      TableField groupByField,
      OrderPair sortByPair,
      int limitValue,
      int offsetValue,
      ORMapper finalMapper}) :
        this._joins = joins,
        this._whereCondition = whereCondition,
        this._havingCondition = havingCondition,
        this._groupByField = groupByField,
        this._sortByPair = sortByPair,
        this._offsetValue = offsetValue,
        this._limitValue = limitValue,
        this._finalMapper = finalMapper;

  Query<T> update({
      Iterable<Join> joins,
      Condition whereCondition,
      Condition havingCondition,
      TableField groupByField,
      OrderPair sortByPair,
      int limitValue,
      int offsetValue,
      ORMapper finalMapper}) {
    return new Query(_mapper,
        joins: joins ?? this._joins,
        whereCondition: whereCondition ?? this._whereCondition,
        havingCondition: havingCondition ?? this._havingCondition,
        groupByField: groupByField ?? this._groupByField,
        sortByPair: sortByPair ?? this._sortByPair,
        offsetValue: offsetValue ?? this._offsetValue,
        limitValue: limitValue ?? this._limitValue,
        finalMapper: finalMapper ?? this._finalMapper);
  }

  Future<Option<T>> first() async {
    var list = await all();
    return list.isNotEmpty ? new Some(list.first) : const None();
  }

  Future<Iterable<T>> all() {
    Select sql = select(((_finalMapper ?? _mapper) as ORMapper).table.f.all).from([_mapper.table]);
    if (_joins != null && _joins.isNotEmpty) {
      sql = _joins.fold(sql, (Select sql, Join join) {
        return sql.innerJoin(join.mapper.table).on(join.condition);
      });
    }
    if (_whereCondition != null) {
      sql = sql.where(_whereCondition);
    }
    if (_sortByPair != null) {
      sql = sql.orderBy(_sortByPair.field, _sortByPair.modifier);
    }
    if (_groupByField != null) {
      sql = sql.groupBy([_groupByField]);
    }
    if (_havingCondition != null) {
      sql = sql.having(_havingCondition);
    }
    if (_limitValue != null) {
      sql = sql.limit(_limitValue);
    }
    if (_offsetValue != null) {
      sql = sql.offset(_offsetValue);
    }
    return _mapper.execute(sql.toSql(), ((_finalMapper ?? _mapper) as ORMapper).modelFactory);
  }

  Query merge(Query query) {
    var newWhereCondition;
    if (_whereCondition != null && query._whereCondition != null) {
      newWhereCondition = _whereCondition.and(query._whereCondition);
    } else if (_whereCondition != null) {
      newWhereCondition = _whereCondition;
    } else if (query._whereCondition != null) {
      newWhereCondition = query._whereCondition;
    }

    var newHavingCondition;
    if (_havingCondition != null && query._havingCondition != null) {
      newHavingCondition = _havingCondition.and(query._havingCondition);
    } else if (_havingCondition != null) {
      newHavingCondition = _havingCondition;
    } else if (query._havingCondition != null) {
      newHavingCondition = query._havingCondition;
    }

    return update(
        joins: []..addAll(_joins ?? [])..addAll(query._joins ?? []),
        whereCondition: newWhereCondition,
        havingCondition: newHavingCondition,
        groupByField: _groupByField ?? query._groupByField,
        sortByPair: _sortByPair ?? query._sortByPair,
        offsetValue: _offsetValue ?? query._offsetValue,
        limitValue: _limitValue ?? query._limitValue);
  }

  Query belongsTo(int id, ORMapper joinMapper, TableField joinField) {
    return addJoin(joinMapper, joinField.eqToField(joinMapper.table.primaryKey))
        .where(_mapper.table.primaryKey.eqToObj(id))
        .update(finalMapper: joinMapper);
  }

  Query hasMany(int id, ORMapper joinMapper, TableField joinField) {
    return addJoin(joinMapper, joinField.eqToField(_mapper.table.primaryKey))
        .where(_mapper.table.primaryKey.eqToObj(id))
        .update(finalMapper: joinMapper);
  }

  Query addRelations(Iterable<Relation> relations) {
    return relations.fold(this, (Query query, relation) {
      TableField baseField;
      if (relation.baseField != null) {
        baseField = relation.baseField;
      } else {
        ORMapper previousMapper = query._joins != null && query._joins.isNotEmpty ? query._joins.last.mapper : _mapper;
        baseField = previousMapper.table.primaryKey;
      }
      return query.addJoin(relation.mapper, relation.joinField.eqToField(baseField));
    });
  }

  Query hasManyThrough(int id, Iterable<Relation> relations) {
    return addRelations(relations)
        .where(_mapper.table.primaryKey.eqToObj(id))
        .update(finalMapper: relations.last.mapper);
  }

  Query hasAndBelongsToMany(int id, ORMapper intermediateMapper, ORMapper targetMapper, TableField sourceField, TableField targetField) {
    return hasManyThrough(id, [
      new Relation(intermediateMapper, sourceField),
      new Relation(targetMapper, targetMapper.table.primaryKey, targetField)]);
  }

  Query<T> where(Condition condition) {
    return update(whereCondition: _whereCondition?.and(condition) ?? condition);
  }

  Query<T> having(Condition condition) {
    return update(havingCondition: _havingCondition?.and(condition) ?? condition);
  }

  Query<T> groupBy(TableField field) {
    return update(groupByField: field);
  }

  Query<T> sortBy(TableField field, [String type = "ASC"]) {
    return update(sortByPair: new OrderPair(field, type == "ASC" ? OrderModifier.ASC : OrderModifier.DESC));
  }

  Query<T> limit(int number) {
    return update(limitValue: number);
  }

  Query<T> offset(int number) {
    return update(offsetValue: number);
  }

  Query addJoin(ORMapper joinMapper, Condition condition) {
    var join = new Join(
        JoinType.innerJoin,
        joinMapper,
        condition);
    return update(joins: new List.from(_joins ?? [])..add(join));
  }
}
