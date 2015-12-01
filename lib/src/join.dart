library ormapper.join;

import 'package:ormapper/ormapper.dart';
import 'package:squilder/squilder.dart';

class Join {
  final JoinType type;
  final ORMapper mapper;
  final Condition condition;
  Join(this.type, this.mapper, this.condition);
}
