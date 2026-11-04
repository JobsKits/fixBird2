import 'dart:convert';
import 'package:flutter/services.dart';

typedef Json = Map<String, dynamic>;
Json object(Object? value) {
  if (value is! Map) throw const FormatException('响应应为对象');
  return Map<String, dynamic>.from(value);
}

List<Json> records(Object? value) {
  if (value is! List) throw const FormatException('响应应为列表');
  return value.map(object).toList();
}

Json clone(Json value) => object(jsonDecode(jsonEncode(value)));
String text(Json value, String key) => value[key]?.toString() ?? '';
int integer(Json value, String key) =>
    value[key] is int ? value[key] as int : 0;
String money(Object? cents) =>
    '¥${((cents is num ? cents : 0) / 100).toStringAsFixed(2)}';

class WorkbenchContract {
  WorkbenchContract(this.data);
  final Json data;
  static Future<WorkbenchContract> load() async => WorkbenchContract(
    object(
      jsonDecode(
        await rootBundle.loadString(
          'packages/repair_shared/assets/admin-ui.json',
        ),
      ),
    ),
  );
  List<Json> list(String key) => records(data[key]);
  String label(String key) => text(object(data['labels']), key);
  String state(String code) =>
      list('states').firstWhere(
            (row) => row['value'] == code,
            orElse: () => {'label': code},
          )['label']
          as String;
  Json? action(String type) {
    for (final item in list('actions')) {
      if (item['type'] == type) return item;
    }
    return null;
  }

  static Json actor(Object? value) {
    final row = object(value);
    for (final key in ['id', 'name', 'role', 'companyId']) {
      if (row[key] is! String || (row[key] as String).isEmpty) {
        throw FormatException('身份字段缺失：$key');
      }
    }
    if (row['status'] != 'active' ||
        row['authVersion'] is! int ||
        row['authVersion'] < 1) {
      throw const FormatException('身份授权无效');
    }
    return row;
  }

  static bool sameActor(Json a, Json b) => [
    'id',
    'role',
    'companyId',
    'authVersion',
  ].every((key) => a[key] == b[key]);
  static Json order(Object? value, {bool detail = false}) {
    final row = object(value);
    for (final key in ['id', 'number', 'status', 'device']) {
      if (row[key] is! String || (row[key] as String).isEmpty) {
        throw FormatException('工单缺少$key');
      }
    }
    if (row['version'] is! int ||
        row['version'] < 1 ||
        row['allowedActions'] is! List ||
        (row['allowedActions'] as List).any((e) => e is! String)) {
      throw const FormatException('工单版本或动作无效');
    }
    if (detail && row['isSummary'] == true)
      throw const FormatException('摘要不能当作详情');
    final summary = object(row['summary']);
    if (summary['missing'] is! List ||
        (summary['missing'] as List).any((e) => e is! String)) {
      throw const FormatException('工单缺项结构无效');
    }
    for (final key in [
      'collectedCents',
      'receivableCents',
      'remainingCents',
      'pendingCashCents',
    ]) {
      if (summary[key] is! int) throw FormatException('工单金额无效：$key');
    }
    for (final cash in records(row['cash'])) {
      if (text(cash, 'id').isEmpty ||
          cash['amountCents'] is! int ||
          !['receipt', 'refund'].contains(cash['kind'])) {
        throw const FormatException('现金记录无效');
      }
    }
    for (final key in [
      'events',
      'evidence',
      'invoices',
      'issues',
      'obligations',
      'costs',
      'commissions',
      'visits',
    ]) {
      records(row[key]);
    }
    return row;
  }
}
