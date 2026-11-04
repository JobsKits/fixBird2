import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:repair_shared/repair_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  const endpoint = String.fromEnvironment('API_TEST_URL');
  final contract = WorkbenchContract(
    object(jsonDecode(File('assets/admin-ui.json').readAsStringSync())),
  );
  test('真实Go API：管理员登录、完整详情、幂等写入、资料与角色导出', () async {
    expect(endpoint, startsWith('http://127.0.0.1:'));
    final store = WorkbenchStore(
      contract,
      endpoint: endpoint,
      timeout: const Duration(seconds: 15),
    );
    addTearDown(store.dispose);
    await store.login('admin', 'Demo-Repair-2026!');
    expect(store.synthetic, false);
    expect(store.actor!['role'], 'admin');
    expect(store.orders, isNotEmpty);
    final current = await store.detail(text(store.orders.first, 'id'));
    expect(current['isSummary'], isNot(true));
    final created = await store.create({
      'type': 'onsite',
      'customer': 'Flutter集成合成客户',
      'customerId': 'customer',
      'companyId': 'company-a',
      'project': '隔离回归机房',
      'device': 'Flutter回归控制柜',
      'description': '仅合成测试，验证新端真实请求',
    });
    expect(created['id'], isNotEmpty);
    final taken = await store.act(created, 'intake', {
      'ownerId': 'dispatcher',
      'assigneeId': 'engineer',
    });
    expect(taken['status'], 'pending_arrangement');
    expect(taken['version'], greaterThan(created['version'] as int));
    final diagnosed = await store.act(taken, 'diagnose', {
      'note': 'Flutter端真实API检测',
    });
    final quoted = await store.act(diagnosed, 'quote', {
      'amountCents': 12345,
      'description': 'Flutter回归更换及测试',
      'warrantyMonths': 3,
      'paymentTerms': 'credit',
      'prepayCents': 0,
      'startRequiresPrepayment': false,
      'validUntil': DateTime.now()
          .add(const Duration(days: 3))
          .toUtc()
          .toIso8601String(),
      'autoAccept': false,
    });
    expect(object(quoted['quote'])['amountCents'], 12345);
    final remarked = await store.act(quoted, 'remark', {
      'remark': 'Flutter真实API回归备注',
    });
    expect(remarked['remark'], 'Flutter真实API回归备注');
    final exported = await store.exportData();
    expect(object(exported['actor'])['id'], 'admin');
    final accounts = await store.accounts();
    expect(accounts.any((a) => a['id'] == 'engineer'), true);
    final audit = await store.audit(1);
    expect(audit['items'], isA<List>());
    final savedSettings = await store.write('/settings', {
      for (final key in [
        'companyAddress',
        'companyReceiver',
        'companyPhone',
        'reminderHours',
        'remarkLimit',
      ])
        key: store.settings[key],
    });
    expect(savedSettings['companyAddress'], store.settings['companyAddress']);
    await store.logout();
    expect(store.actor, isNull);
  });
  test('真实Go API：客户读取隔离及401撤销', () async {
    final store = WorkbenchStore(
      contract,
      endpoint: endpoint,
      timeout: const Duration(seconds: 15),
    );
    addTearDown(store.dispose);
    await store.login('customer-b', 'Demo-Repair-2026!');
    expect(store.synthetic, false);
    expect(store.orders.every((o) => o['companyId'] == 'company-b'), true);
    store.token = 'deliberately-invalid-in-isolated-test';
    await store.reload();
    expect(store.actor, isNull);
    expect(store.orders, isEmpty);
    expect(store.token, isEmpty);
  });
}
