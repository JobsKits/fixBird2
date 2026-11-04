import 'dart:convert';
import '../../../../../代码/前端/共享组件/Flutter/lib/src/contract.dart';
import '../../../../../代码/前端/共享组件/Flutter/lib/src/demo.dart';

void main() {
  final seed = object(
    jsonDecode(
      '{"parts":[],"purchases":[],"orders":[{"id":"one","number":"D1","status":"pending_intake","device":"测试","quote":{}},{"id":"two","number":"D2","status":"pending_customer_confirmation","device":"测试","quote":{"amountCents":128000}},{"id":"three","number":"D3","status":"repairing","device":"测试","quote":{"amountCents":68000}}]}',
    ),
  );
  final contract = WorkbenchContract({
    'roles': [
      {'id': 'admin', 'label': '合成管理员'},
    ],
    'actions': <Json>[],
    'seed': seed,
  });
  final demo = DemoLedger(contract),
      snapshot = demo.snapshot(demo.identity('admin'));
  final remaining = object(snapshot['metrics'])['remainingCents'];
  print('actualDemoLedger.remainingCents=$remaining');
  print('actualFormatter=${money(remaining)}');
  if (remaining != 196000 || money(remaining) != '¥1960.00')
    throw StateError('Web运行时待收金额合同不一致');
}
