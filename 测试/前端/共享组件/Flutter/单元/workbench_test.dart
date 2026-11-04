import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repair_shared/repair_shared.dart';
import 'package:repair_shared/src/demo.dart';
import 'package:repair_shared/src/form.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('packages/repair_shared/NotoSansSC')
      ..addFont(rootBundle.load('assets/NotoSansSC.ttf'));
    await loader.load();
  });
  final contract = WorkbenchContract(
    object(jsonDecode(File('assets/admin-ui.json').readAsStringSync())),
  );
  Json bootstrap(DemoLedger demo, Json actor) => {
    ...demo.snapshot(actor),
    'orderPage': {'page': 1, 'total': 3, 'totalPages': 1, 'pageSize': 30},
  };
  http.Response json(Object? value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  WorkbenchStore offline() => WorkbenchStore(
    contract,
    endpoint: 'http://127.0.0.1:1',
    client: MockClient((_) async => throw const SocketException('offline')),
  );
  test('管理Web和Flutter共享契约字节一致', () {
    expect(
      File('assets/admin-ui.json').readAsBytesSync(),
      File('../../后台管理端/共享契约/admin-ui.json').readAsBytesSync(),
    );
  });
  test('全部API动作都有表单定义', () {
    expect(contract.list('actions').length, 43);
    expect(contract.list('actions').map((e) => e['type']).toSet().length, 43);
  });
  test('无法连接API时载入独立合成演示', () async {
    final s = offline();
    await s.login('admin', 'demo');
    expect(s.synthetic, true);
    expect(s.orders.length, 3);
    expect(s.metrics['remainingCents'], 196000);
    expect(s.token, isEmpty);
    s.dispose();
  });
  test('HTTP登录拒绝不进入假登录', () async {
    final s = WorkbenchStore(
      contract,
      endpoint: 'http://example.test',
      client: MockClient((_) async => json({'message': '禁止登录'}, 403)),
    );
    await expectLater(s.login('admin', 'wrong'), throwsA(isA<ApiFailure>()));
    expect(s.actor, isNull);
    s.dispose();
  });
  test('客户演示不读取内部成本与其它企业工单', () async {
    final s = offline();
    await s.login('customer-b', 'demo');
    expect(s.orders, isEmpty);
    expect(s.parts, isEmpty);
    await s.login('customer', 'demo');
    expect(s.orders.length, 3);
    expect(s.orders.every((o) => o['remark'] == ''), true);
    s.dispose();
  });
  test('演示维修主链正常推进', () {
    final d = DemoLedger(contract), admin = d.identity('admin');
    var row = d.detail('demo-intake', admin);
    Json act(String type, Json p) {
      row = d.write('/orders/${row['id']}/actions', {
        'type': type,
        'version': row['version'],
        'payload': p,
      }, admin);
      return row;
    }

    act('intake', {'ownerId': 'dispatcher', 'assigneeId': 'engineer'});
    act('diagnose', {});
    expect(row['status'], 'diagnosis_quotation');
    expect(
      () => act('quote', {'amountCents': 10000, 'prepayCents': 20000}),
      throwsStateError,
    );
    act('quote', {
      'amountCents': 10000,
      'prepayCents': 0,
      'description': '检测更换',
      'validUntil': DateTime.now()
          .add(const Duration(days: 3))
          .toIso8601String(),
    });
    act('approve_quote', {});
    expect(row['status'], 'pending_customer_confirmation');
    expect(row['version'], 5);
  });
  test('完结工单不能新增义务', () {
    final d = DemoLedger(contract), actor = d.identity('admin');
    d.orders.first['status'] = 'completed';
    final o = d.detail('demo-intake', actor);
    expect(o['allowedActions'], isNot(contains('obligation')));
    expect(
      () => d.write('/orders/demo-intake/actions', {
        'type': 'obligation',
        'version': 1,
        'payload': {'title': '不应办理'},
      }, actor),
      throwsStateError,
    );
  });
  test('仓库不能批准耗用及超额归还', () {
    final d = DemoLedger(contract), warehouse = d.identity('warehouse');
    final loan = d.write('/loans', {
      'partId': 'part-board',
      'borrowerId': 'engineer',
      'quantity': 2,
    }, warehouse);
    expect(
      () => d.write('/loans/${loan['id']}/actions', {
        'type': 'consume',
        'version': 1,
        'payload': {'quantity': 1, 'reason': '测试'},
      }, warehouse),
      throwsStateError,
    );
    expect(
      () => d.write('/loans/${loan['id']}/actions', {
        'type': 'return',
        'version': 1,
        'payload': {'quantity': 3, 'condition': 'good'},
      }, warehouse),
      throwsStateError,
    );
    expect(d.loans.first['outstanding'], 2);
    expect(d.parts.first['available'], 26);
  });
  test('独立借用没有关联工单不能转维修耗用', () {
    final d = DemoLedger(contract), admin = d.identity('admin');
    final loan = d.write('/loans', {
      'partId': 'part-board',
      'borrowerId': 'engineer',
      'quantity': 2,
    }, admin);
    expect(
      () => d.write('/loans/${loan['id']}/actions', {
        'type': 'consume',
        'version': 1,
        'payload': {'quantity': 1, 'reason': '消耗'},
      }, admin),
      throwsStateError,
    );
  });
  test('采购部分入库守恒，超收原子拒绝', () {
    final d = DemoLedger(contract), a = d.identity('admin');
    d.write('/purchases/demo-purchase/receive', {
      'version': 1,
      'quantity': 2,
    }, a);
    expect(d.parts.first['available'], 30);
    expect(
      () => d.write('/purchases/demo-purchase/receive', {
        'version': 2,
        'quantity': 5,
      }, a),
      throwsStateError,
    );
    expect(d.parts.first['available'], 30);
  });
  test('公司设置需要管理员且校验失败保持原值', () {
    final d = DemoLedger(contract), admin = d.identity('admin');
    final before = clone(d.settings);
    expect(
      () => d.write('/settings', {
        'companyAddress': '',
        'reminderHours': 0,
      }, admin),
      throwsStateError,
    );
    expect(d.settings, before);
    final values = {
      'companyAddress': '合成维修中心',
      'companyReceiver': '合成人员',
      'companyPhone': '000-00000000',
      'reminderHours': 48,
      'remarkLimit': 2000,
    };
    expect(
      () => d.write('/settings', values, d.identity('engineer')),
      throwsStateError,
    );
    d.write('/settings', values, admin);
    expect(object(d.snapshot(admin)['settings'])['reminderHours'], 48);
  });
  test('调度不能代收件，外包在当前指派单可开修', () {
    final d = DemoLedger(contract), dispatcher = d.identity('dispatcher');
    d.orders.first['status'] = 'pending_arrangement';
    expect(
      d.detail('demo-intake', dispatcher)['allowedActions'],
      isNot(contains('receive')),
    );
    expect(
      () => d.write('/orders/demo-intake/actions', {
        'type': 'receive',
        'version': 1,
        'payload': {},
      }, dispatcher),
      throwsStateError,
    );
    final outsource = d.identity('outsource');
    d.orders.first['assigneeId'] = 'outsource';
    d.orders.first['status'] = 'pending_execution';
    d.orders.first['quote'] = {'version': 1, 'approved': true, 'signed': true};
    expect(
      d.detail('demo-intake', outsource)['allowedActions'],
      contains('start'),
    );
    final result = d.write('/orders/demo-intake/actions', {
      'type': 'start',
      'version': 1,
      'payload': {},
    }, outsource);
    expect(result['status'], 'repairing');
  });
  test('上下文按服务合同过滤：上门、返修、复核与本人余项', () {
    final d = DemoLedger(contract),
        admin = d.identity('admin'),
        finance = d.identity('finance');
    final row = d.orders.first;
    row['type'] = 'mail';
    row['outcome'] = 'accepted';
    var actions = d.detail('demo-intake', admin)['allowedActions'] as List;
    expect(actions, isNot(contains('visit')));
    expect(actions, isNot(contains('rework')));
    expect(actions, isNot(contains('review_acceptance')));
    row['acceptedAt'] = DateTime.now().toUtc().toIso8601String();
    row['status'] = 'pending_acceptance';
    row['restartReview'] = true;
    actions = d.detail('demo-intake', admin)['allowedActions'] as List;
    expect(actions, contains('rework'));
    expect(actions, contains('review_acceptance'));
    row['obligations'] = [
      {'id': 'other-task', 'ownerId': 'engineer', 'resolved': false},
    ];
    expect(
      d.detail('demo-intake', finance)['allowedActions'],
      isNot(contains('resolve_obligation')),
    );
    row['obligations'] = [
      {'id': 'own-task', 'ownerId': 'finance', 'resolved': false},
    ];
    expect(
      d.detail('demo-intake', finance)['allowedActions'],
      contains('resolve_obligation'),
    );
  });
  test('开修未结异议拒绝，采购调度可登记但不可收货', () {
    final d = DemoLedger(contract), engineer = d.identity('engineer');
    d.orders.first['status'] = 'pending_execution';
    d.orders.first['quote'] = {'approved': true, 'signed': true};
    d.orders.first['issues'] = [
      {'id': 'issue', 'resolved': false},
    ];
    expect(
      () => d.write('/orders/demo-intake/actions', {
        'type': 'start',
        'version': 1,
        'payload': {},
      }, engineer),
      throwsStateError,
    );
    final dispatcher = d.identity('dispatcher');
    final purchase = d.write('/purchases', {
      'partId': 'part-board',
      'supplier': 'supplier',
      'quantity': 2,
      'unitCents': 100,
    }, dispatcher);
    expect(
      () => d.write('/purchases/${purchase['id']}/receive', {
        'quantity': 1,
        'version': 1,
      }, dispatcher),
      throwsStateError,
    );
    expect(purchase['received'], 0);
  });
  test('库存读取按内部、本人借用及供应商采购隔离', () {
    final d = DemoLedger(contract);
    d.loans = [
      {'id': 'mine', 'borrowerId': 'engineer'},
      {'id': 'other', 'borrowerId': 'other-engineer'},
    ];
    final engineer = d.snapshot(d.identity('engineer'));
    expect(records(engineer['loans']).map((e) => e['id']), ['mine']);
    expect(records(d.snapshot(d.identity('supplier'))['parts']), isEmpty);
    expect(records(d.snapshot(d.identity('outsource'))['purchases']), isEmpty);
    expect(records(d.snapshot(d.identity('supplier'))['purchases']).length, 1);
  });
  test('工单完结需借用解除阻塞及提成结清，拒绝后不改版本', () {
    final d = DemoLedger(contract), admin = d.identity('admin');
    final row = d.orders.first;
    row['status'] = 'pending_completion';
    row['outcome'] = 'accepted';
    row['documents'] = {'requirement': 'none'};
    row['invoiceRequirement'] = 'none';
    row['receivableCents'] = 0;
    d.loans.add({
      'id': 'loan',
      'orderId': row['id'],
      'outstanding': 2,
      'transfers': [
        {'quantity': 1},
      ],
    });
    Json complete() => d.write('/orders/${row['id']}/actions', {
      'type': 'complete',
      'version': 1,
      'payload': {},
    }, admin);
    expect(() => complete(), throwsStateError);
    expect(d.orders.first['version'], 1);
    d.loans.first['transfers'] = [
      {'quantity': 2},
    ];
    row['commissions'] = [
      {'id': 'commission', 'settled': false},
    ];
    expect(() => complete(), throwsStateError);
    expect(d.orders.first['version'], 1);
    row['commissions'] = [
      {'id': 'commission', 'settled': true},
    ];
    expect(complete()['status'], 'completed');
    expect(d.orders.first['version'], 2);
  });
  test('服务恢复后真实快照替换演示', () async {
    var available = false;
    final demo = DemoLedger(contract), actor = demo.identity('admin');
    final s = WorkbenchStore(
      contract,
      endpoint: 'http://example.test',
      client: MockClient((r) async {
        if (!available) throw const SocketException('offline');
        return r.url.path.endsWith('/login')
            ? json({'token': 'token', 'actor': actor})
            : json(bootstrap(demo, actor));
      }),
    );
    await s.login('admin', 'demo');
    expect(s.synthetic, true);
    available = true;
    await s.reload();
    expect(s.synthetic, false);
    expect(s.token, 'token');
    s.dispose();
  });
  test('当前401撤销会话并清私有快照', () async {
    var unauthorized = false;
    final demo = DemoLedger(contract), actor = demo.identity('admin');
    final s = WorkbenchStore(
      contract,
      endpoint: 'http://example.test',
      client: MockClient((r) async {
        if (unauthorized) return json({'message': '已撤销'}, 401);
        return r.url.path.endsWith('/login')
            ? json({'token': 'token', 'actor': actor})
            : json(bootstrap(demo, actor));
      }),
    );
    await s.login('admin', 'demo');
    unauthorized = true;
    await s.reload();
    expect(s.actor, isNull);
    expect(s.orders, isEmpty);
    expect(s.token, isEmpty);
    s.dispose();
  });
  test('坏响应身份不能替换当前身份', () async {
    final d = DemoLedger(contract), actor = d.identity('admin');
    final s = WorkbenchStore(
      contract,
      endpoint: 'http://example.test',
      client: MockClient(
        (r) async => r.url.path.endsWith('/login')
            ? json({'token': 'token', 'actor': actor})
            : json(bootstrap(d, d.identity('customer'))),
      ),
    );
    await s.login('admin', 'demo');
    expect(s.synthetic, true);
    expect(s.actor!['role'], 'admin');
    s.dispose();
  });
  test('现金缺金额时拒绝采纳为真账', () {
    final row = DemoLedger(
      contract,
    ).snapshot(DemoLedger(contract).identity('admin'));
    final order = records(row['orders']).first;
    order['cash'] = [
      {'id': 'cash', 'kind': 'receipt'},
    ];
    expect(() => WorkbenchContract.order(order), throwsFormatException);
  });
  test('未知提交同内容重试沿用幂等键', () async {
    final d = DemoLedger(contract), actor = d.identity('admin');
    final keys = <String>[];
    final s = WorkbenchStore(
      contract,
      endpoint: 'http://example.test',
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login'))
          return json({'token': 't', 'actor': actor});
        if (r.url.path.endsWith('/bootstrap')) return json(bootstrap(d, actor));
        keys.add(r.headers['Idempotency-Key']!);
        throw const SocketException('lost');
      }),
    );
    await s.login('admin', 'demo');
    final order = s.orders.first;
    await expectLater(
      s.act(order, 'remark', {'remark': '测试'}),
      throwsException,
    );
    await expectLater(
      s.act(order, 'remark', {'remark': '测试'}),
      throwsException,
    );
    expect(keys.length, 2);
    expect(keys.first, keys.last);
    expect(s.synthetic, false);
    s.dispose();
  });
  test('旧工单版本成功回包不能误报保存成功', () async {
    final d = DemoLedger(contract), actor = d.identity('admin');
    final s = WorkbenchStore(
      contract,
      endpoint: 'http://example.test',
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login'))
          return json({'token': 't', 'actor': actor});
        if (r.url.path.endsWith('/bootstrap')) return json(bootstrap(d, actor));
        return json(d.detail('demo-intake', actor));
      }),
    );
    await s.login('admin', 'demo');
    await expectLater(
      s.act(s.orders.first, 'remark', {'remark': '测试'}),
      throwsFormatException,
    );
    expect(s.message, contains('未确认'));
    s.dispose();
  });
  test('导出身份不匹配拒绝采用', () async {
    final d = DemoLedger(contract), actor = d.identity('admin');
    final s = WorkbenchStore(
      contract,
      endpoint: 'http://example.test',
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login'))
          return json({'token': 't', 'actor': actor});
        if (r.url.path.endsWith('/bootstrap')) return json(bootstrap(d, actor));
        return json(d.snapshot(d.identity('customer')));
      }),
    );
    await s.login('admin', 'demo');
    await expectLater(s.exportData(), throwsFormatException);
    s.dispose();
  });
  test('环境切换清理身份和未确认意图', () async {
    final s = offline();
    await s.login('admin', 'demo');
    s.configure('https://example.com', 2);
    expect(s.actor, isNull);
    expect(s.orders, isEmpty);
    expect(s.endpoint, 'https://example.com');
    expect(
      () => s.configure('https://user:pass@example.com/path', 2),
      throwsFormatException,
    );
    s.dispose();
  });
  test('旧登录迟到不能覆盖新身份', () async {
    final pending = Completer<http.Response>();
    final s = WorkbenchStore(
      contract,
      endpoint: 'http://example.test',
      client: MockClient((_) => pending.future),
    );
    final login = s.login('admin', 'demo');
    s.configure('https://another.example', 2);
    pending.complete(
      json({'token': 'old', 'actor': DemoLedger(contract).identity('admin')}),
    );
    await expectLater(login, throwsStateError);
    expect(s.actor, isNull);
    s.dispose();
  });
  test('手写签名编码为真实PNG', () async {
    final image = await signaturePng([
      [const Offset(.1, .2), const Offset(.8, .7)],
    ]);
    expect(image, startsWith('data:image/png;base64,iVBOR'));
  });
  test('测试与线上地址独立保存，切换后不继承会话', () async {
    SharedPreferences.setMockInitialValues({});
    final s = offline();
    await s.login('admin', 'demo');
    await s.configureEnvironment(
      'test',
      'http://127.0.0.1:8098',
      'https://repair.example.com',
      2.5,
    );
    expect(s.actor, isNull);
    final restored = offline();
    await restored.loadEnvironment();
    expect(restored.endpoint, 'http://127.0.0.1:8098');
    expect(restored.productionEndpoint, 'https://repair.example.com');
    await restored.configureEnvironment(
      'production',
      restored.testEndpoint,
      restored.productionEndpoint,
      2.5,
    );
    expect(restored.endpoint, 'https://repair.example.com');
    expect(restored.testEndpoint, 'http://127.0.0.1:8098');
    s.dispose();
    restored.dispose();
  });
  for (final width in [390.0, 1200.0]) {
    testWidgets(
      '管理页${width.toInt()}宽屏无溢出',
      (tester) async {
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = offline();
        await s.login('admin', 'demo');
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: WorkbenchApp(store: s, admin: true),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('管理工作台'), findsOneWidget);
        expect(find.text('待收金额'), findsOneWidget);
        final reloadButton = find.widgetWithText(OutlinedButton, '重新加载');
        expect(
          tester
              .getSize(
                find.descendant(
                  of: reloadButton,
                  matching: find.byType(Material),
                ),
              )
              .height,
          44,
        );
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final pixels = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '验证/admin-flutter-${width.toInt()}.png',
          ).writeAsBytes(pixels!.buffer.asUint8List());
          image.dispose();
        });
        await s.logout();
        await tester.pumpAndSettle();
        expect(find.text('登录工作台'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final pixels = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '验证/admin-flutter-login-${width.toInt()}.png',
          ).writeAsBytes(pixels!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
        s.dispose();
      },
      variant: TargetPlatformVariant({
        width == 1200 ? TargetPlatform.macOS : TargetPlatform.android,
      }),
    );
  }
  testWidgets('390窄卡大金额单行缩放且指标卡等高', (tester) async {
    tester.view.physicalSize = const Size(390, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = offline();
    await s.login('admin', 'demo');
    s.metrics['remainingCents'] = 99999999999;
    await tester.pumpWidget(WorkbenchApp(store: s, admin: true));
    await tester.pumpAndSettle();
    final value = find.text('¥999999999.99');
    expect(value, findsOneWidget);
    final text = tester.widget<Text>(value);
    expect(text.maxLines, 1);
    expect(text.softWrap, false);
    final moneyCard = find.ancestor(of: value, matching: find.byType(Card));
    final neighbour = find.ancestor(
      of: find.text('待完结'),
      matching: find.byType(Card),
    );
    expect(tester.getSize(moneyCard).height, tester.getSize(neighbour).height);
    final paragraph = tester.renderObject<RenderBox>(value),
        cardRect = tester.getRect(moneyCard);
    final left = paragraph.localToGlobal(Offset.zero),
        right = paragraph.localToGlobal(
          paragraph.size.bottomRight(Offset.zero),
        );
    expect(left.dx, greaterThanOrEqualTo(cardRect.left + 19.5));
    expect(right.dx, lessThanOrEqualTo(cardRect.right - 19.5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));
}
