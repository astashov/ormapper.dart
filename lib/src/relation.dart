library ormapper.relation;

import 'package:ormapper/ormapper.dart';
import 'package:squilder/squilder.dart';

class Relation<M, TF> {
  final ORMapper<M> mapper;
  final TableField<TF> joinField;
  final TableField baseField;
  Relation(this.mapper, this.joinField, [this.baseField]);
}
