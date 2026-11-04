import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'contract.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'demo.dart';

class ApiFailure implements Exception {
  ApiFailure(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

/// 会话、读取顺序与提交意图分别隔离，避免旧响应污染新身份。
class WorkbenchStore extends ChangeNotifier {
  WorkbenchStore(
    this.contract, {
    http.Client? client,
    String? endpoint,
    this.timeout = const Duration(milliseconds: 2500),
  }) : client = client ?? http.Client(),
       endpoint = endpoint ?? const String.fromEnvironment('API_URL'),
       demo = DemoLedger(contract);
  final WorkbenchContract contract;
  final http.Client client;
  final DemoLedger demo;
  String endpoint;
  Duration timeout;
  String environmentMode = 'test';
  String themeName = 'system';
  String testEndpoint = '';
  String productionEndpoint = '';
  Future<void> loadEnvironment() async {
    final prefs = await SharedPreferences.getInstance();
    testEndpoint = prefs.getString('repair.testEndpoint') ?? endpoint;
    productionEndpoint = prefs.getString('repair.productionEndpoint') ?? '';
    environmentMode = prefs.getString('repair.environment') ?? 'test';
    themeName = prefs.getString('repair.theme') ?? 'system';
    endpoint = environmentMode == 'production'
        ? productionEndpoint
        : testEndpoint;
  }

  Future<void> saveTheme(String value) async {
    themeName = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('repair.theme', value);
  }

  Future<void> configureEnvironment(
    String mode,
    String test,
    String production,
    double seconds,
  ) async {
    if (!['test', 'production'].contains(mode))
      throw const FormatException('环境无效');
    for (final address in [test, production]) {
      validateEndpoint(address);
    }
    configure(mode == 'production' ? production : test, seconds);
    environmentMode = mode;
    testEndpoint = test.trim();
    productionEndpoint = production.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('repair.testEndpoint', testEndpoint);
    await prefs.setString('repair.productionEndpoint', productionEndpoint);
    await prefs.setString('repair.environment', mode);
  }

  static void validateEndpoint(String address) {
    final raw = address.trim();
    final uri = Uri.tryParse(raw);
    if (raw.isNotEmpty &&
        (uri == null ||
            !['http', 'https'].contains(uri.scheme) ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            uri.hasQuery ||
            uri.hasFragment ||
            uri.path.isNotEmpty && uri.path != '/'))
      throw const FormatException('请输入HTTP/HTTPS服务根地址，不含凭据、路径或参数');
  }

  Json? actor;
  String token = '';
  String username = '';
  String password = '';
  bool synthetic = true;
  bool busy = false;
  String message = '请选择账号登录；服务不可用时使用独立合成演示。';
  List<Json> orders = [], parts = [], loans = [], purchases = [];
  Json metrics = {}, settings = {};
  int total = 0, page = 1, totalPages = 1;
  String query = '', status = '';
  int _generation = 0, _revision = 0, _sequence = 0;
  final Map<String, String> _intents = {};

  void _clear() {
    _generation++;
    _revision++;
    actor = null;
    token = '';
    orders = [];
    parts = [];
    loans = [];
    purchases = [];
    metrics = {};
    settings = {};
    _intents.clear();
    total = 0;
    page = 1;
    totalPages = 1;
    busy = false;
    synthetic = true;
  }

  void configure(String value, double seconds) {
    final raw = value.trim();
    final uri = Uri.tryParse(raw);
    if (raw.isNotEmpty &&
        (uri == null ||
            !['http', 'https'].contains(uri.scheme) ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            uri.hasQuery ||
            uri.hasFragment ||
            (uri.path.isNotEmpty && uri.path != '/'))) {
      throw const FormatException('请输入完整 HTTP/HTTPS 服务地址，不含路径、账号或参数');
    }
    if (!seconds.isFinite || seconds < 0.5 || seconds > 30) {
      throw const FormatException('超时范围为0.5～30秒');
    }
    _clear();
    username = '';
    password = '';
    endpoint = raw.replaceAll(RegExp(r'/$'), '');
    timeout = Duration(milliseconds: (seconds * 1000).round());
    message = '地址已切换，请重新登录。';
    notifyListeners();
  }

  Future<Object?> request(
    String path, {
    String method = 'GET',
    Json? body,
    String? intent,
  }) async {
    final captured = _generation;
    final base = endpoint.isEmpty ? Uri.base.origin : endpoint;
    final uri = Uri.parse('$base/api/v38$path');
    final response = await client
        .send(
          http.Request(method, uri)
            ..headers.addAll({
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
              if (intent != null) 'Idempotency-Key': intent,
            })
            ..body = body == null ? '' : jsonEncode(body),
        )
        .then(http.Response.fromStream)
        .timeout(timeout);
    if (captured != _generation) throw StateError('旧会话响应已忽略');
    Object? value;
    try {
      value = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      if (response.statusCode >= 200 && response.statusCode < 300)
        throw const FormatException('服务器返回内容无法解析');
    }
    if (response.statusCode == 401) {
      _clear();
      username = '';
      password = '';
      message = '会话已失效，请重新登录。';
      notifyListeners();
      throw ApiFailure(401, message);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiFailure(
        response.statusCode,
        value is Map
            ? '${value['message'] ?? '请求被拒绝'}'
            : '服务错误 ${response.statusCode}',
      );
    }
    return value;
  }

  Future<void> _authenticate() async {
    if (token.isNotEmpty) return;
    final value = object(
      await request(
        '/login',
        method: 'POST',
        body: {'username': username, 'password': password},
      ),
    );
    final authenticated = WorkbenchContract.actor(value['actor']);
    if (value['token'] is! String || (value['token'] as String).isEmpty)
      throw const FormatException('登录令牌无效');
    token = value['token'] as String;
    actor = authenticated;
  }

  Future<void> login(String name, String secret) async {
    if (busy) return;
    _clear();
    username = name.trim();
    password = secret;
    final captured = _generation;
    busy = true;
    notifyListeners();
    try {
      await _authenticate();
      await _readBootstrap();
      message = '已连接服务端。';
    } catch (error) {
      if (captured != _generation) rethrow;
      if (error is ApiFailure && error.status < 500) {
        message = error.message;
        rethrow;
      }
      final roles = contract.list('roles').map((e) => e['id']);
      if (!roles.contains(username) || password.isEmpty) {
        actor = null;
        message = '服务不可用。请选择合成账号体验。';
        rethrow;
      }
      token = '';
      actor = demo.identity(username);
      _useDemo();
      message = 'API暂不可用，已载入独立合成演示；重新加载继续尝试服务。';
    } finally {
      if (captured == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void _useDemo() {
    synthetic = true;
    final snapshot = demo.snapshot(actor!);
    orders = records(snapshot['orders']);
    parts = records(snapshot['parts']);
    loans = records(snapshot['loans']);
    purchases = records(snapshot['purchases']);
    metrics = object(snapshot['metrics']);
    settings = object(snapshot['settings']);
    total = orders.length;
    totalPages = 1;
    page = 1;
    if (query.isNotEmpty)
      orders = orders
          .where(
            (o) => jsonEncode(o).toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    if (status.isNotEmpty)
      orders = orders.where((o) => o['status'] == status).toList();
  }

  Future<void> _readBootstrap() async {
    final snapshot = object(await request('/bootstrap'));
    final current = WorkbenchContract.actor(snapshot['actor']);
    if (actor == null || !WorkbenchContract.sameActor(current, actor!))
      throw const FormatException('响应身份与登录身份不一致');
    final nextOrders = records(
      snapshot['orders'],
    ).map((e) => WorkbenchContract.order(e)).toList();
    final nextParts = records(snapshot['parts']);
    for (final part in nextParts) {
      if (text(part, 'id').isEmpty ||
          part['available'] is! int ||
          part['quarantine'] is! int)
        throw const FormatException('库存响应无效');
    }
    final nextLoans = records(snapshot['loans']);
    for (final loan in nextLoans) {
      _validateLoan(loan);
    }
    final nextPurchases = records(snapshot['purchases']);
    for (final purchase in nextPurchases) {
      _validatePurchase(purchase);
    }
    final nextMetrics = object(snapshot['metrics']);
    for (final entry in contract.list('metrics')) {
      if (nextMetrics[entry['key']] is! int)
        throw const FormatException('概览指标无效');
    }
    final pagination = object(snapshot['orderPage']);
    orders = nextOrders;
    parts = nextParts;
    loans = nextLoans;
    purchases = nextPurchases;
    metrics = nextMetrics;
    settings = object(snapshot['settings']);
    synthetic = false;
    total = integer(pagination, 'total');
    page = integer(pagination, 'page');
    totalPages = integer(pagination, 'totalPages');
  }

  void _validateLoan(Json row) {
    if (text(row, 'id').isEmpty ||
        row['version'] is! int ||
        row['version'] < 1 ||
        text(row, 'partId').isEmpty ||
        [
          'quantity',
          'returnedGood',
          'returnedQuarantine',
          'consumed',
          'disposed',
          'outstanding',
        ].any((key) => row[key] is! int)) {
      throw const FormatException('借还响应无效');
    }
  }

  void _validatePurchase(Json row) {
    if (text(row, 'id').isEmpty ||
        row['version'] is! int ||
        row['version'] < 1 ||
        text(row, 'partId').isEmpty ||
        ['quantity', 'received', 'unitCents'].any((key) => row[key] is! int))
      throw const FormatException('采购响应无效');
  }

  Future<void> reload({int targetPage = 1}) async {
    if (actor == null || busy) return;
    final captured = _generation, revision = ++_revision;
    busy = true;
    notifyListeners();
    try {
      await _authenticate();
      await _readBootstrap();
      if (query.isNotEmpty || status.isNotEmpty || targetPage != 1) {
        final result = object(
          await request(
            '/orders?page=$targetPage&pageSize=30&q=${Uri.encodeQueryComponent(query)}&status=${Uri.encodeQueryComponent(status)}',
          ),
        );
        if (captured != _generation || revision != _revision) return;
        final items = records(
          result['items'],
        ).map((e) => WorkbenchContract.order(e)).toList();
        orders = items;
        total = integer(result, 'total');
        page = integer(result, 'page');
        totalPages = integer(result, 'totalPages');
      }
      message = '已更新服务端数据。';
    } catch (error) {
      if (captured != _generation) return;
      if (error is ApiFailure && error.status < 500) {
        message = '$error';
      } else {
        token = '';
        _useDemo();
        message = '服务不可用，当前为独立合成演示：$error';
      }
    } finally {
      if (captured == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<Json> detail(String id) async {
    if (synthetic) {
      // 每次进入详情也探测服务，恢复后重新打开真实记录。
      await reload();
      if (!synthetic) throw StateError('服务已恢复，请在真实列表重新选择工单。');
      if (actor == null) throw ApiFailure(401, '会话已失效，请重新登录。');
      return demo.detail(id, actor!);
    }
    final result = WorkbenchContract.order(
      await request('/orders/${Uri.encodeComponent(id)}'),
      detail: true,
    );
    if (result['id'] != id) throw const FormatException('工单编号不匹配');
    return result;
  }

  String _key(String intent) => _intents.putIfAbsent(
    intent,
    () => 'flutter-${DateTime.now().microsecondsSinceEpoch}-${++_sequence}',
  );
  Future<Json> write(
    String path,
    Json body, {
    Json? prior,
    String? action,
  }) async {
    if (busy || actor == null) throw StateError('请等待当前请求完成');
    if (synthetic) {
      await reload();
      if (!synthetic) throw StateError('服务已恢复，请重新选择真实记录后提交。');
      if (actor == null) throw StateError('请重新登录');
      final value = demo.write(path, body, actor!);
      _useDemo();
      message = '已保存到独立合成演示，未写入服务端。';
      notifyListeners();
      return value;
    }
    final captured = _generation;
    final fingerprint = '$path:${jsonEncode(body)}';
    busy = true;
    notifyListeners();
    try {
      final value = object(
        await request(
          path,
          method: 'POST',
          body: body,
          intent: _key(fingerprint),
        ),
      );
      if (path.startsWith('/orders')) {
        WorkbenchContract.order(value, detail: true);
        if (prior != null) {
          if (action == 'rework') {
            if (value['id'] == prior['id'] ||
                value['originalOrderId'] != prior['id'])
              throw const FormatException('返修子单关系错误');
          } else if (value['id'] != prior['id'] ||
              integer(value, 'version') <= integer(prior, 'version')) {
            throw const FormatException('工单版本未推进，请重新核对提交结果');
          }
        }
      } else if (path.startsWith('/loans')) {
        _validateLoan(value);
      } else if (path.startsWith('/purchases')) {
        _validatePurchase(value);
      }
      _intents.remove(fingerprint);
      message = '服务端已确认保存。';
      return value;
    } catch (error) {
      if (error is ApiFailure && error.status < 500)
        _intents.remove(fingerprint);
      message = error is ApiFailure
          ? '$error'
          : '提交结果未确认。请保留表单并用同样内容重试，避免重复登记。';
      rethrow;
    } finally {
      if (captured == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<Json> create(Json values) => write('/orders', values);
  Future<Json> act(Json order, String type, Json payload) => write(
    '/orders/${order['id']}/actions',
    {'type': type, 'version': order['version'], 'payload': payload},
    prior: order,
    action: type,
  );
  Future<List<Json>> accounts() async {
    if (synthetic) throw StateError('账号管理需要连接服务端');
    if (actor?['role'] != 'admin') throw StateError('仅管理员可管理账号');
    return records(await request('/accounts'));
  }

  Future<Json> audit(int page) async {
    if (synthetic) throw StateError('审计查询需要连接服务端');
    if (actor?['role'] != 'admin') throw StateError('仅管理员可读取审计记录');
    return object(await request('/audit?page=$page&pageSize=30'));
  }

  Future<void> setAccountStatus(String id, String status, String reason) async {
    if (synthetic || actor?['role'] != 'admin')
      throw StateError('请连接服务并使用管理员账号');
    if (id == actor?['id'] && status == 'disabled')
      throw StateError('不能停用当前账号');
    final body = {'status': status, 'reason': reason};
    final fingerprint = '/accounts/$id/status:${jsonEncode(body)}';
    await request(
      '/accounts/${Uri.encodeComponent(id)}/status',
      method: 'POST',
      body: body,
      intent: _key(fingerprint),
    );
    _intents.remove(fingerprint);
  }

  Future<Json> exportData() async {
    if (![
      'admin',
      'dispatcher',
      'finance',
      'customer',
    ].contains(actor?['role']))
      throw StateError('当前角色无导出权限');
    if (synthetic) throw StateError('导出授权数据需要连接服务端');
    final value = synthetic
        ? demo.snapshot(actor!)
        : object(await request('/export'));
    if (actor == null ||
        !WorkbenchContract.sameActor(
          WorkbenchContract.actor(value['actor']),
          actor!,
        )) {
      throw const FormatException('导出身份不匹配');
    }
    return value;
  }

  Future<void> logout() async {
    if (token.isNotEmpty) {
      final pending = request('/logout', method: 'POST', body: {});
      _clear();
      username = '';
      password = '';
      message = '已退出，私有缓存已清除。';
      notifyListeners();
      try {
        await pending;
      } catch (_) {
        /* 已清除本地身份，旧退出结果不覆盖新会话。 */
      }
    } else {
      _clear();
      username = '';
      password = '';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }
}
