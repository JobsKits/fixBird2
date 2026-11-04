import 'contract.dart';

/// 独立合成账本不接收真实快照；未实现的复杂动作明确拒绝。
class DemoLedger {
  DemoLedger(this.contract) {
    final seed = clone(object(contract.data['seed']));
    parts = records(seed['parts']);
    purchases = records(seed['purchases']);
    orders = records(seed['orders']).map(_defaults).toList();
  }
  final WorkbenchContract contract;
  late List<Json> orders, parts, purchases;
  List<Json> loans = [];
  Json settings = {
    'companyAddress': '合成演示地址：上海市示范路38号',
    'companyReceiver': '演示收件人',
    'companyPhone': '000-00000000',
    'reminderHours': 24,
    'remarkLimit': 2000,
    'demo': true,
  };
  int serial = 100;
  String now() => DateTime.now().toUtc().toIso8601String();
  String next(String prefix) => '$prefix-${++serial}';
  Json identity(String id) => {
    'id': id,
    'username': id,
    'name': contract.list('roles').firstWhere((e) => e['id'] == id)['label'],
    'role': id == 'customer-b' ? 'customer' : id,
    'companyId': id == 'customer'
        ? 'company-a'
        : id == 'customer-b'
        ? 'company-b'
        : id == 'supplier'
        ? 'supplier-demo'
        : 'internal',
    'status': 'active',
    'authVersion': 1,
  };
  Json _defaults(Json row) {
    row['createdAt'] ??= now();
    row['updatedAt'] ??= now();
    row['assigneeId'] ??= 'engineer';
    row['ownerId'] ??= 'dispatcher';
    row['quote'] ??= <String, dynamic>{};
    row['documents'] ??= {
      'requirement': 'unknown',
      'prepared': false,
      'sent': false,
      'files': <String>[],
    };
    row['invoiceRequirement'] ??= 'unknown';
    for (final key in [
      'cash',
      'invoices',
      'events',
      'evidence',
      'issues',
      'obligations',
      'costs',
      'commissions',
      'visits',
    ]) {
      row[key] ??= <Json>[];
    }
    row['remark'] ??= '';
    row['customerNote'] ??= '';
    return row;
  }

  bool _visible(Json row, Json actor) {
    if (actor['role'] == 'customer')
      return row['customerId'] == actor['id'] &&
          row['companyId'] == actor['companyId'];
    if (['engineer', 'outsource'].contains(actor['role']))
      return row['assigneeId'] == actor['id'];
    return actor['role'] != 'supplier';
  }

  bool _permitted(String action, String role) {
    final allowed = switch (action) {
      'sign_quote' || 'accept' => ['customer'],
      'intake' ||
      'assign' ||
      'approve_quote' ||
      'failure' ||
      'complete' ||
      'reopen' ||
      'rework' ||
      'requirements' ||
      'outsource' ||
      'obligation' ||
      'resolve_issue' ||
      'review_acceptance' ||
      'handover_contact' => ['admin', 'dispatcher'],
      'quote' ||
      'diagnose' ||
      'report' => ['admin', 'dispatcher', 'engineer', 'outsource'],
      'start' ||
      'finish' ||
      'start_visit' => ['admin', 'engineer', 'outsource'],
      'receive' || 'stock_ready' || 'dispatch' => ['admin', 'warehouse'],
      'qc' => ['admin', 'qc'],
      'deliver' => ['admin', 'warehouse', 'engineer', 'dispatcher'],
      'verify_cash' ||
      'handover_cash' ||
      'invoice' ||
      'void_invoice' ||
      'adjust_receivable' ||
      'approve_cost' ||
      'commission' ||
      'settle_commission' => ['admin', 'finance'],
      'documents' => ['admin', 'dispatcher', 'finance'],
      'cash' ||
      'cost' => ['admin', 'dispatcher', 'finance', 'engineer', 'warehouse'],
      'visit' => ['admin', 'dispatcher', 'engineer'],
      'remark' || 'resolve_obligation' => [
        'admin',
        'dispatcher',
        'engineer',
        'warehouse',
        'qc',
        'finance',
      ],
      'issue' || 'evidence' || 'delete_evidence' => [
        'admin',
        'dispatcher',
        'engineer',
        'warehouse',
        'qc',
        'finance',
        'customer',
        'outsource',
      ],
      _ => <String>[],
    };
    return allowed.contains(role);
  }

  List<String> _actions(Json row, Json actor) {
    const stages = {
      'intake': ['pending_intake'],
      'receive': ['pending_arrangement', 'pending_quality_check'],
      'diagnose': ['pending_arrangement'],
      'report': ['diagnosis_quotation'],
      'quote': [
        'diagnosis_quotation',
        'pending_customer_confirmation',
        'pending_execution',
      ],
      'approve_quote': ['diagnosis_quotation'],
      'sign_quote': ['pending_customer_confirmation'],
      'start': ['pending_execution'],
      'finish': ['repairing'],
      'qc': ['pending_quality_check'],
      'stock_ready': ['pending_execution'],
      'dispatch': ['pending_delivery'],
      'deliver': ['pending_delivery'],
      'accept': ['pending_acceptance'],
      'complete': ['pending_completion'],
      'reopen': ['completed'],
    };
    return contract.list('actions').map((e) => e['type'] as String).where((
      action,
    ) {
      if (!_permitted(action, actor['role'] as String)) return false;
      if (row['status'] == 'completed' &&
          ![
            'reopen',
            'rework',
            'remark',
            'evidence',
            'delete_evidence',
            'handover_contact',
          ].contains(action))
        return false;
      if (stages.containsKey(action) &&
          !stages[action]!.contains(row['status']))
        return false;
      if (action == 'start' && row['type'] == 'sale' ||
          action == 'stock_ready' && row['type'] != 'sale')
        return false;
      if (['visit', 'start_visit'].contains(action) && row['type'] != 'onsite')
        return false;
      if (action == 'rework' && text(row, 'acceptedAt').isEmpty) return false;
      if (action == 'failure' && text(row, 'outcome').isNotEmpty) return false;
      if (action == 'review_acceptance' &&
          (row['status'] != 'pending_acceptance' ||
              row['restartReview'] != true))
        return false;
      if (action == 'resolve_obligation' &&
          !records(row['obligations']).any(
            (task) =>
                task['resolved'] != true &&
                (['admin', 'dispatcher'].contains(actor['role']) ||
                    task['ownerId'] == actor['id']),
          ))
        return false;
      return true;
    }).toList();
  }

  Json _view(Json row, Json actor) {
    final result = clone(row);
    final full = ['admin', 'dispatcher', 'finance'].contains(actor['role']);
    if (!full) {
      result['costs'] = actor['role'] == 'engineer'
          ? records(
              result['costs'],
            ).where((e) => e['ownerId'] == actor['id']).toList()
          : <Json>[];
      result['commissions'] = <Json>[];
      result['cash'] = records(result['cash'])
          .where((e) => e['verified'] == true || e['collector'] == actor['id'])
          .toList();
      if (!['engineer'].contains(actor['role'])) result['remark'] = '';
    }
    if (['customer', 'outsource', 'supplier'].contains(actor['role'])) {
      result['visits'] = <Json>[];
      result['remark'] = '';
    }
    result['allowedActions'] = _actions(row, actor);
    final quote = object(result['quote']);
    final cash = records(row['cash']);
    final collected = cash
        .where((e) => e['verified'] == true)
        .fold<int>(
          0,
          (s, e) =>
              s + (e['kind'] == 'refund' ? -1 : 1) * integer(e, 'amountCents'),
        );
    final receivable = row['receivableCents'] is int
        ? row['receivableCents'] as int
        : integer(quote, 'amountCents');
    final pending = cash
        .where((e) => e['verified'] != true)
        .fold<int>(0, (s, e) => s + integer(e, 'amountCents'));
    final missing = <String>[];
    if (text(row, 'outcome').isEmpty) missing.add('等待履约完成及客户验收');
    if (receivable > collected) missing.add('应收尚未结清');
    if (pending > 0) missing.add('现金尚未核实');
    if (cash.any((e) => e['verified'] == true && e['handedOver'] != true))
      missing.add('现金尚未内部交接');
    if (records(row['issues']).any((e) => e['resolved'] != true))
      missing.add('存在未解决异议');
    if (records(row['obligations']).any((e) => e['resolved'] != true))
      missing.add('存在未办妥余项');
    if (loans.where((loan) => loan['orderId'] == row['id']).any((loan) {
      final transferred = records(
        loan['transfers'] ?? <Json>[],
      ).fold<int>(0, (sum, item) => sum + integer(item, 'quantity'));
      return integer(loan, 'outstanding') - transferred > 0;
    }))
      missing.add('关联借用尚未归还、耗用或获准独立跟踪');
    if (records(
      row['commissions'],
    ).any((commission) => commission['settled'] != true))
      missing.add('提成尚未结清');
    final docs = object(row['documents']);
    if (docs['requirement'] == 'unknown') missing.add('资料需求待确认');
    if (docs['requirement'] == 'required' && docs['sent'] != true)
      missing.add('付款资料尚未发送');
    if (row['invoiceRequirement'] == 'unknown') missing.add('发票需求待确认');
    if (row['invoiceRequirement'] == 'required' &&
        records(row['invoices']).isEmpty)
      missing.add('尚未开票');
    result['summary'] = {
      'missing': missing,
      'collectedCents': collected,
      'receivableCents': receivable,
      // JavaScript 位移按32位处理；十进制上界在VM和Web中保持相同金额语义。
      'remainingCents': (receivable - collected).clamp(0, 1125899906842624),
      'pendingCashCents': pending,
      'nextTask': missing.isEmpty ? '可申请整单完结' : missing.first,
      'documentStatus': docs['sent'] == true ? '已发送' : '待办理',
      'invoiceStatus': records(row['invoices']).isEmpty ? '待办理' : '已开票',
    };
    return result;
  }

  Json snapshot(Json actor) {
    final visible = orders
        .where((o) => _visible(o, actor))
        .map((o) => _view(o, actor))
        .toList();
    final internal = [
      'admin',
      'dispatcher',
      'engineer',
      'warehouse',
      'qc',
      'finance',
    ].contains(actor['role']);
    return {
      'actor': actor,
      'orders': visible,
      'parts': internal ? parts : <Json>[],
      'loans': loans
          .where(
            (loan) =>
                ['admin', 'warehouse', 'dispatcher'].contains(actor['role']) ||
                actor['role'] == 'engineer' &&
                    loan['borrowerId'] == actor['id'],
          )
          .toList(),
      'purchases': purchases
          .where(
            (purchase) =>
                [
                  'admin',
                  'warehouse',
                  'finance',
                  'dispatcher',
                ].contains(actor['role']) ||
                actor['role'] == 'supplier' &&
                    [actor['id'], actor['name']].contains(purchase['supplier']),
          )
          .toList(),
      'metrics': {
        'openCount': visible.where((o) => o['status'] != 'completed').length,
        'settlingCount': visible.where((o) => o['status'] == 'settling').length,
        'remainingCents': visible.fold<int>(
          0,
          (n, o) => n + integer(object(o['summary']), 'remainingCents'),
        ),
        'readyCount': visible
            .where((o) => o['status'] == 'pending_completion')
            .length,
        'tasksCount': visible.fold<int>(
          0,
          (n, o) =>
              n +
              records(
                o['obligations'],
              ).where((task) => task['resolved'] != true).length,
        ),
        'blockedCount': visible
            .where(
              (o) => records(o['issues']).any((e) => e['resolved'] != true),
            )
            .length,
      },
      'settings': clone(settings),
    };
  }

  Json detail(String id, Json actor) {
    final row = orders.firstWhere(
      (e) => e['id'] == id && _visible(e, actor),
      orElse: () => throw StateError('工单不可见，请重新加载'),
    );
    return _view(row, actor);
  }

  Never reject(String message) => throw StateError(message);
  Json write(String path, Json body, Json actor) {
    if (path == '/settings') {
      if (actor['role'] != 'admin') reject('公司设置只能由管理员修改');
      if ([
            'companyAddress',
            'companyReceiver',
            'companyPhone',
          ].any((key) => text(body, key).trim().isEmpty) ||
          integer(body, 'reminderHours') < 1 ||
          integer(body, 'reminderHours') > 168 ||
          integer(body, 'remarkLimit') < 100 ||
          integer(body, 'remarkLimit') > 10000)
        reject('寄送信息必填，提醒1～168小时，备注100～10000字');
      settings = {...body, 'demo': true};
      return clone(settings);
    }
    if (path == '/orders') {
      if (!['admin', 'dispatcher', 'customer'].contains(actor['role']))
        reject('当前角色不能录单');
      if ([
        'customer',
        'project',
        'device',
        'description',
      ].any((key) => text(body, key).trim().isEmpty))
        reject('请填写客户、位置、设备及故障描述');
      final row = _defaults({
        ...body,
        'id': next('demo'),
        'number': 'DEMO-${serial.toString().padLeft(4, '0')}',
        'version': 1,
        'status': 'pending_intake',
      });
      if (actor['role'] == 'customer') {
        row['customerId'] = actor['id'];
        row['companyId'] = actor['companyId'];
      }
      orders.insert(0, row);
      return _view(row, actor);
    }
    if (path == '/loans' || path.startsWith('/loans/'))
      return _loan(path, body, actor);
    if (path == '/purchases' || path.startsWith('/purchases/'))
      return _purchase(path, body, actor);
    final id = path.split('/')[2];
    final current = orders.firstWhere(
      (e) => e['id'] == id && _visible(e, actor),
      orElse: () => reject('工单不可见'),
    );
    if (body['version'] != current['version']) reject('版本已变化，请重新打开工单');
    final type = text(body, 'type'), payload = object(body['payload']);
    if (!_actions(current, actor).contains(type)) reject('当前角色或阶段不能执行此动作');
    final row = clone(current), quote = object(row['quote']);
    final note = text(payload, 'note');
    switch (type) {
      case 'intake':
        row['ownerId'] = payload['ownerId'];
        row['assigneeId'] = payload['assigneeId'];
        row['status'] = 'pending_arrangement';
      case 'receive':
        break;
      case 'assign':
        row['assigneeId'] = payload['assigneeId'];
      case 'diagnose':
        row['status'] = 'diagnosis_quotation';
      case 'report':
        if (note.trim().isEmpty) reject('请填写检测报告');
      case 'quote':
        final amount = integer(payload, 'amountCents'),
            prepay = integer(payload, 'prepayCents');
        if (amount < 0 ||
            amount == 0 && row['freeRework'] != true ||
            prepay < 0 ||
            prepay > amount)
          reject('报价或预付款金额不合法');
        if (payload['startRequiresPrepayment'] == true && prepay <= 0)
          reject('先款开修需要有效预付款');
        if (text(payload, 'description').trim().isEmpty ||
            DateTime.tryParse(
                  text(payload, 'validUntil'),
                )?.isAfter(DateTime.now()) !=
                true)
          reject('请填写报价范围及未来有效期');
        row['quote'] = {
          ...payload,
          'version': integer(quote, 'version') + 1,
          'approved': false,
          'signed': false,
        };
        row['receivableCents'] = amount;
        row['status'] = 'diagnosis_quotation';
      case 'approve_quote':
        if (integer(quote, 'version') < 1) reject('请先制定报价');
        quote['approved'] = true;
        row['quote'] = quote;
        row['status'] = 'pending_customer_confirmation';
      case 'sign_quote':
        if (quote['approved'] != true ||
            payload['quoteVersion'] != quote['version'] ||
            !text(payload, 'signature').startsWith('data:image/png;base64,'))
          reject('报价版本或手写签名无效');
        if (quote['validUntil'] != null &&
            DateTime.tryParse(
                  text(quote, 'validUntil'),
                )?.isAfter(DateTime.now()) !=
                true)
          reject('报价已过期');
        quote['signed'] = true;
        quote['signature'] = payload['signature'];
        quote['signedAt'] = now();
        row['quote'] = quote;
        row['status'] = 'pending_execution';
      case 'start':
        if (quote['approved'] != true ||
            quote['signed'] != true ||
            records(row['issues']).any((issue) => issue['resolved'] != true))
          reject('报价须批准并签署，异议须解决后才能执行');
        if (quote['startRequiresPrepayment'] == true &&
            integer(object(_view(row, actor)['summary']), 'collectedCents') <
                integer(quote, 'prepayCents'))
          reject('约定预付款尚未核实');
        row['status'] = 'repairing';
      case 'finish':
        row['status'] = 'pending_quality_check';
      case 'qc':
        row['status'] = payload['passed'] == true
            ? 'pending_delivery'
            : 'repairing';
      case 'stock_ready':
        reject('独立演示暂不模拟销售出库，请连接服务办理');
      case 'dispatch':
        if (text(payload, 'carrier').isEmpty ||
            text(payload, 'tracking').isEmpty)
          reject('请填写承运人与运单号');
      case 'deliver':
        final date = DateTime.tryParse(text(payload, 'deliveredAt'));
        if (date == null ||
            date.isAfter(DateTime.now()) ||
            date.isBefore(DateTime.parse(text(row, 'createdAt'))))
          reject('交付时间必须在创建时间与当前时间之间');
        row['deliveredAt'] = date.toUtc().toIso8601String();
        row['status'] = 'pending_acceptance';
      case 'accept':
        if (!text(payload, 'signature').startsWith('data:image/png;base64,'))
          reject('请手写验收签名');
        if (payload['passed'] == true) {
          row['outcome'] = 'accepted';
          row['acceptedAt'] = now();
          row['status'] = 'settling';
        } else {
          (row['issues'] as List).add({
            'id': next('issue'),
            'title': note,
            'ownerId': 'dispatcher',
            'resolved': false,
          });
        }
        (row.putIfAbsent('acceptanceRecords', () => <Json>[]) as List).add({
          'id': next('accept'),
          'passed': payload['passed'],
          'signature': payload['signature'],
          'signerName': actor['name'],
          'signedAt': now(),
        });
      case 'remark':
        if (payload.containsKey('remark') &&
            [
              'admin',
              'dispatcher',
              'finance',
              'engineer',
            ].contains(actor['role']))
          row['remark'] = payload['remark'];
        if (payload.containsKey('customerNote'))
          row['customerNote'] = payload['customerNote'];
      case 'requirements':
        row['documents'] = {
          ...object(row['documents']),
          'requirement': payload['documentRequirement'],
          'reason': payload['documentReason'],
        };
        row['invoiceRequirement'] = payload['invoiceRequirement'];
        row['invoiceReason'] = payload['invoiceReason'];
        row['invoiceDueCents'] = payload['invoiceDueCents'];
      case 'documents':
        if (payload['sent'] == true &&
            (payload['prepared'] != true ||
                text(payload, 'recipient').trim().isEmpty ||
                (payload['files'] as List? ?? []).isEmpty))
          reject('发送资料必须已制作、指定原件和接收对象');
        row['documents'] = {...object(row['documents']), ...payload};
      case 'cash':
        if (integer(payload, 'amountCents') <= 0 ||
            !['receipt', 'refund'].contains(payload['kind']))
          reject('收退款金额必须大于零');
        (row['cash'] as List).add({
          ...payload,
          'id': next('cash'),
          'collector': actor['id'],
          'verified': false,
          'handedOver': false,
        });
      case 'verify_cash':
        final cash = records(row['cash']).firstWhere(
          (e) => e['id'] == payload['cashId'],
          orElse: () => reject('现金记录不存在'),
        );
        if (cash['verified'] == true) reject('该记录已核实');
        if (cash['kind'] == 'refund' &&
            integer(cash, 'amountCents') >
                integer(object(_view(row, actor)['summary']), 'collectedCents'))
          reject('退款不能超过净核实收款');
        (row['cash'] as List).firstWhere(
          (e) => e['id'] == payload['cashId'],
        )['verified'] = true;
      case 'handover_cash':
        final cash = (row['cash'] as List).firstWhere(
          (e) => e['id'] == payload['cashId'],
          orElse: () => reject('现金记录不存在'),
        );
        if (cash['verified'] != true) reject('请先核实现金');
        cash['handedOver'] = true;
      case 'adjust_receivable':
        if (text(payload, 'reason').trim().isEmpty ||
            integer(payload, 'amountCents') < 0)
          reject('请填写调整原因和非负金额');
        row['receivableCents'] = payload['amountCents'];
      case 'evidence':
        if (text(payload, 'name').isEmpty ||
            text(payload, 'text').isEmpty && text(payload, 'data').isEmpty)
          reject('请填写内容或选择文件');
        (row['evidence'] as List).add({
          ...payload,
          'id': next('file'),
          'uploaderId': actor['id'],
          'createdAt': now(),
          'stage': row['status'],
          'deleted': false,
        });
      case 'delete_evidence':
        final item = (row['evidence'] as List).firstWhere(
          (e) => e['id'] == payload['evidenceId'],
          orElse: () => reject('资料不存在'),
        );
        if (text(payload, 'reason').isEmpty) reject('请填写删除原因');
        item['deleted'] = true;
      case 'issue':
      case 'obligation':
        if ((type == 'issue' ? note : text(payload, 'title')).trim().isEmpty)
          reject('请填写事项说明');
        (row[type == 'issue' ? 'issues' : 'obligations'] as List).add({
          'id': next(type),
          'title': type == 'issue' ? note : payload['title'],
          'ownerId': payload['ownerId'],
          'dueAt': payload['dueAt'],
          'resolved': false,
        });
      case 'resolve_issue':
      case 'resolve_obligation':
        final task =
            (row[type == 'resolve_issue' ? 'issues' : 'obligations'] as List)
                .firstWhere(
                  (e) =>
                      e['id'] ==
                      payload[type == 'resolve_issue'
                          ? 'issueId'
                          : 'obligationId'],
                  orElse: () => reject('事项不存在'),
                );
        if (type == 'resolve_obligation' &&
            !['admin', 'dispatcher'].contains(actor['role']) &&
            task['ownerId'] != actor['id'])
          reject('只有责任人或公司调度可以办理');
        if (type == 'resolve_issue' && row['status'] == 'pending_acceptance')
          reject('演示暂不模拟验收窗口恢复，请连接服务办理');
        task['resolved'] = true;
        task['resolution'] = note;
      case 'complete':
        if ((object(_view(row, actor)['summary'])['missing'] as List)
            .isNotEmpty)
          reject('资料、票款或余项未齐，暂不能完结');
        row['status'] = 'completed';
      case 'reopen':
        if (text(payload, 'reason').isEmpty) reject('请说明重开原因');
        row['status'] = 'settling';
      case 'failure':
        if (text(row, 'outcome').isNotEmpty) reject('已有履约结果，不能覆盖');
        row['outcome'] = 'failed';
        row['status'] = 'settling';
        row['receivableCents'] = payload['amountCents'];
      default:
        reject('此动作的独立演示暂未适配，请连接服务端办理');
    }
    row['version'] = integer(row, 'version') + 1;
    row['updatedAt'] = now();
    (row['events'] as List).add({
      'id': next('event'),
      'title': contract.action(type)?['label'] ?? type,
      'note': note,
      'actorName': actor['name'],
      'at': now(),
    });
    orders[orders.indexOf(current)] = row;
    return _view(row, actor);
  }

  Json _loan(String path, Json body, Json actor) {
    if (!['admin', 'warehouse'].contains(actor['role'])) reject('借还操作需要仓库或管理员');
    if (path == '/loans') {
      final part = parts.firstWhere(
        (e) => e['id'] == body['partId'],
        orElse: () => reject('配件不存在'),
      );
      final qty = integer(body, 'quantity');
      if (qty <= 0 ||
          qty > integer(part, 'available') ||
          body['borrowerId'] != 'engineer')
        reject('数量不足或责任人不是有效工程师');
      final orderId = text(body, 'orderId');
      if (orderId.isNotEmpty &&
          orders.any((o) => o['id'] == orderId && o['status'] == 'completed'))
        reject('完结单必须重开后借用');
      final row = {
        ...body,
        'id': next('loan'),
        'version': 1,
        'partName': part['name'],
        'returnedGood': 0,
        'returnedQuarantine': 0,
        'consumed': 0,
        'disposed': 0,
        'outstanding': qty,
      };
      part['available'] = integer(part, 'available') - qty;
      loans.add(row);
      return clone(row);
    }
    final row = loans.firstWhere(
      (e) => e['id'] == path.split('/')[2],
      orElse: () => reject('借用不存在'),
    );
    if (row['version'] != body['version']) reject('借用版本已变化');
    final payload = object(body['payload']),
        type = text(body, 'type'),
        qty = integer(object(body['payload']), 'quantity');
    if (qty <= 0 || qty > integer(row, 'outstanding')) reject('数量超出尚欠范围');
    final part = parts.firstWhere((e) => e['id'] == row['partId']);
    if (type == 'return') {
      if (!['good', 'quarantine'].contains(payload['condition']))
        reject('归还状态无效');
      final key = payload['condition'] == 'good'
          ? 'returnedGood'
          : 'returnedQuarantine';
      row[key] = integer(row, key) + qty;
      final stock = payload['condition'] == 'good' ? 'available' : 'quarantine';
      part[stock] = integer(part, stock) + qty;
    } else {
      if (actor['role'] != 'admin') reject('耗用、处置与转出必须管理员批准');
      if (text(payload, 'reason').trim().isEmpty) reject('请填写批准原因');
      if (type == 'consume' && text(row, 'orderId').isEmpty)
        reject('维修耗用需要关联工单');
      if (!['consume', 'dispose'].contains(type)) reject('独立转出跟踪暂未适配，请连接服务办理');
      final key = type == 'consume' ? 'consumed' : 'disposed';
      row[key] = integer(row, key) + qty;
    }
    row['outstanding'] = integer(row, 'outstanding') - qty;
    row['version'] = integer(row, 'version') + 1;
    return clone(row);
  }

  Json _purchase(String path, Json body, Json actor) {
    if (!(path == '/purchases'
            ? ['admin', 'warehouse', 'dispatcher']
            : ['admin', 'warehouse'])
        .contains(actor['role']))
      reject('当前角色无此采购办理权限');
    if (path == '/purchases') {
      if (integer(body, 'quantity') <= 0 ||
          integer(body, 'unitCents') < 0 ||
          !parts.any((e) => e['id'] == body['partId']))
        reject('配件、数量或单价无效');
      final row = {
        ...body,
        'id': next('purchase'),
        'version': 1,
        'received': 0,
      };
      purchases.add(row);
      return clone(row);
    }
    final row = purchases.firstWhere(
      (e) => e['id'] == path.split('/')[2],
      orElse: () => reject('采购单不存在'),
    );
    if (row['version'] != body['version']) reject('采购版本已变化');
    final qty = integer(body, 'quantity');
    if (qty <= 0 || qty > integer(row, 'quantity') - integer(row, 'received'))
      reject('收货数量超出待收范围');
    final part = parts.firstWhere((e) => e['id'] == row['partId']);
    part['available'] = integer(part, 'available') + qty;
    row['received'] = integer(row, 'received') + qty;
    row['version'] = integer(row, 'version') + 1;
    return clone(row);
  }
}
