import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'contract.dart';
import 'form.dart';
import 'store.dart';

Future<void> launchWorkbench({required bool admin}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final contract = await WorkbenchContract.load();
  final store = WorkbenchStore(contract);
  await store.loadEnvironment();
  runApp(WorkbenchApp(store: store, admin: admin));
}

class WorkbenchApp extends StatefulWidget {
  const WorkbenchApp({super.key, required this.store, required this.admin});
  final WorkbenchStore store;
  final bool admin;
  @override
  State<WorkbenchApp> createState() => _WorkbenchAppState();
}

class _WorkbenchAppState extends State<WorkbenchApp> {
  ThemeMode mode = ThemeMode.system;
  @override
  void initState() {
    super.initState();
    mode = ThemeMode.values.firstWhere(
      (m) => m.name == widget.store.themeName,
      orElse: () => ThemeMode.system,
    );
  }

  ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = object(widget.store.contract.data['colors']);
    Color c(String key) =>
        Color(int.parse('FF${text(colors, key).substring(1)}', radix: 16));
    final scheme = ColorScheme.fromSeed(
      seedColor: c('primary'),
      brightness: brightness,
      surface: c(dark ? 'darkSurface' : 'surface'),
      onSurface: c(dark ? 'darkText' : 'text'),
      onSurfaceVariant: c(dark ? 'darkSecondary' : 'secondary'),
      primary: c(dark ? 'darkSecondary' : 'primary'),
      onPrimary: dark ? c('darkBackground') : Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      fontFamily: 'packages/repair_shared/NotoSansSC',
      colorScheme: scheme,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 15),
        bodySmall: TextStyle(fontSize: 13),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
      ),
      scaffoldBackgroundColor: c(dark ? 'darkBackground' : 'background'),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
        isDense: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: widget.admin ? '啄木鸟管理工作台' : '啄木鸟维修服务',
    debugShowCheckedModeBanner: false,
    theme: theme(Brightness.light),
    darkTheme: theme(Brightness.dark),
    themeMode: mode,
    home: WorkbenchHome(
      store: widget.store,
      admin: widget.admin,
      mode: mode,
      onTheme: (value) {
        setState(() => mode = value);
        widget.store.saveTheme(value.name);
      },
    ),
  );
}

class WorkbenchHome extends StatefulWidget {
  const WorkbenchHome({
    super.key,
    required this.store,
    required this.admin,
    required this.mode,
    required this.onTheme,
  });
  final WorkbenchStore store;
  final bool admin;
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onTheme;
  @override
  State<WorkbenchHome> createState() => _WorkbenchHomeState();
}

class _WorkbenchHomeState extends State<WorkbenchHome> {
  WorkbenchStore get store => widget.store;
  WorkbenchContract get contract => store.contract;
  String view = 'overview';
  String selectedRole = 'admin';
  final password = TextEditingController(text: 'Demo-Repair-2026!');
  final loginEndpoint = TextEditingController();
  final query = TextEditingController();
  @override
  void initState() {
    super.initState();
    selectedRole = widget.admin ? 'admin' : 'customer';
    loginEndpoint.text = store.endpoint;
    store.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store.removeListener(changed);
    password.dispose();
    loginEndpoint.dispose();
    query.dispose();
    super.dispose();
  }

  void showError(Object error) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
  }

  Future<void> run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      showError(e);
    }
  }

  Widget brand() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'packages/repair_shared/assets/RepairLogo.png',
        width: 36,
        height: 36,
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          text(contract.data, 'brand'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
    ],
  );
  bool get company => [
    'admin',
    'dispatcher',
    'engineer',
    'warehouse',
    'qc',
    'finance',
  ].contains(store.actor?['role']);
  List<Json> get navigation => contract
      .list('navigation')
      .where(
        (e) =>
            widget.admin ||
            company ||
            !['inventory', 'purchases'].contains(e['id']),
      )
      .toList();
  bool canCreate() =>
      ['admin', 'dispatcher', 'customer'].contains(store.actor?['role']);
  Widget empty() => Card(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              contract.label('emptyTitle'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(contract.label('emptyBody')),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: store.busy ? null : () => store.reload(),
              child: Text(contract.label('reload')),
            ),
          ],
        ),
      ),
    ),
  );
  Widget panel(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
  Widget login() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: panel(widget.admin ? '登录管理工作台' : '登录维修服务', [
          const Text('选择账号，进入工单、维修进度及业务办理。'),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: selectedRole,
            decoration: const InputDecoration(labelText: '账号身份'),
            isExpanded: true,
            items: contract
                .list('roles')
                .map(
                  (role) => DropdownMenuItem(
                    value: text(role, 'id'),
                    child: Text('${role['label']} · ${role['id']}'),
                  ),
                )
                .toList(),
            onChanged: store.busy
                ? null
                : (v) => setState(() => selectedRole = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: '密码'),
            onFieldSubmitted: (_) => loginSubmit(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: store.busy ? null : loginSubmit,
            child: Text(store.busy ? '正在连接…' : '登录并进入'),
          ),
          const SizedBox(height: 12),
          Text(store.message),
          const SizedBox(height: 12),
          TextButton(onPressed: configure, child: const Text('设置服务地址')),
          const Text('演示账号只使用合成资料。服务未启动时会自动进入独立演示，刷新后继续尝试连接。'),
        ]),
      ),
    ),
  );
  Widget adminLogin() => Align(
    alignment: Alignment.topCenter,
    child: SingleChildScrollView(
      padding: EdgeInsets.only(
        top: MediaQuery.sizeOf(context).width < 900
            ? 16
            : MediaQuery.sizeOf(context).height * .07,
      ),
      child: SizedBox(
        width: 480,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  text(contract.data, 'brand'),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '管理工作台',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '登录工作台',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  '使用演示账号快速熟悉流程。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('服务地址'),
                const SizedBox(height: 7),
                TextField(
                  controller: loginEndpoint,
                  decoration: const InputDecoration(hintText: '留空使用当前服务'),
                ),
                const SizedBox(height: 14),
                const Text('账号'),
                const SizedBox(height: 7),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  isExpanded: true,
                  items: contract
                      .list('roles')
                      .map(
                        (role) => DropdownMenuItem(
                          value: text(role, 'id'),
                          child: Text('${role['label']}（${role['id']}）'),
                        ),
                      )
                      .toList(),
                  onChanged: store.busy
                      ? null
                      : (v) => setState(() => selectedRole = v!),
                ),
                const SizedBox(height: 14),
                const Text('密码'),
                const SizedBox(height: 7),
                TextField(
                  controller: password,
                  obscureText: true,
                  onSubmitted: (_) => loginSubmit(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: store.busy ? null : loginSubmit,
                  child: Text(store.busy ? '正在连接…' : '进入工作台'),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '演示密码：Demo-Repair-2026!\n连接失败时仅演示账号进入独立合成副本。真实登录被拒绝时不会模拟登录成功。',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () async {
                      final base = store.endpoint.isEmpty
                          ? Uri.base.origin
                          : store.endpoint;
                      await launchUrl(Uri.parse('$base/'));
                    },
                    child: const Text('进入维修协同工作台'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Future<void> loginSubmit() => run(() async {
    if (widget.admin && loginEndpoint.text.trim() != store.endpoint)
      store.configure(loginEndpoint.text, store.timeout.inMilliseconds / 1000);
    await store.login(selectedRole, password.text);
  });
  Future<void> configure() async {
    String mode = store.environmentMode;
    final address = TextEditingController(text: store.endpoint);
    String error = '';
    bool saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('切换服务地址'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('环境'),
                  const SizedBox(height: 7),
                  DropdownButtonFormField<String>(
                    initialValue: mode,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'test', child: Text('测试环境')),
                      DropdownMenuItem(
                        value: 'production',
                        child: Text('线上环境'),
                      ),
                    ],
                    onChanged: saving
                        ? null
                        : (value) => update(() {
                            mode = value!;
                            address.text = mode == 'production'
                                ? store.productionEndpoint
                                : store.testEndpoint;
                          }),
                  ),
                  const SizedBox(height: 14),
                  const Text('服务根地址'),
                  const SizedBox(height: 7),
                  TextField(
                    controller: address,
                    enabled: !saving,
                    decoration: const InputDecoration(hintText: '留空使用当前服务'),
                  ),
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      update(() => saving = true);
                      try {
                        await store.configureEnvironment(
                          mode,
                          mode == 'test' ? address.text : store.testEndpoint,
                          mode == 'production'
                              ? address.text
                              : store.productionEndpoint,
                          store.timeout.inMilliseconds / 1000,
                        );
                        loginEndpoint.text = store.endpoint;
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted)
                          update(() {
                            saving = false;
                            error = '$e';
                          });
                      }
                    },
              child: const Text('确认提交'),
            ),
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
    address.dispose();
  }

  Future<void> create() async {
    await showWorkbenchForm(
      context,
      '新建工单',
      contract.list('createOrder'),
      (payload) async {
        await store.create(payload);
      },
      defaults: store.actor?['role'] == 'customer'
          ? {
              'customerId': store.actor!['id'],
              'companyId': store.actor!['companyId'],
            }
          : {},
    );
    await store.reload();
  }

  Widget metrics() => LayoutBuilder(
    builder: (context, size) {
      final columns = size.maxWidth >= 620 ? 3 : 2;
      final width = (size.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: contract
            .list('metrics')
            .map(
              (metric) => SizedBox(
                width: width,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(text(metric, 'label')),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: size.maxWidth >= 620 ? 44 : 38,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              metric['money'] == true
                                  ? money(store.metrics[metric['key']])
                                  : '${store.metrics[metric['key']] ?? 0}',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: size.maxWidth >= 620 ? 29 : 25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
  Widget overview() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      metrics(),
      const SizedBox(height: 24),
      panel('待办工单', [
        const Text('按工单阶段查看当前可办理事项。'),
        const SizedBox(height: 16),
        ...store.orders.take(5).map(orderTile),
        if (store.orders.isEmpty) empty(),
      ]),
    ],
  );
  Widget badge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1B4F49)
          : const Color(0xFFE0EFEC),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFC6EDE7)
            : const Color(0xFF145D56),
      ),
    ),
  );
  Widget orderTile(Json order) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openOrder(text(order, 'id')),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    text(order, 'number'),
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  badge(contract.state(text(order, 'status'))),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                text(order, 'device'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text('${order['customer']} · ${order['project']}'),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      text(order, 'description'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    money(object(order['quote'])['amountCents']),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget orderGrid() => LayoutBuilder(
    builder: (context, size) {
      final columns = size.maxWidth >= 620 ? 2 : 1;
      return Wrap(
        spacing: 16,
        children: store.orders
            .map(
              (order) => SizedBox(
                width: (size.maxWidth - (columns - 1) * 16) / columns,
                child: orderTile(order),
              ),
            )
            .toList(),
      );
    },
  );
  Widget orders() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: query,
        decoration: InputDecoration(
          labelText: contract.label('search'),
          suffix: TextButton(
            onPressed: store.busy ? null : search,
            child: const Text('搜索'),
          ),
        ),
        onSubmitted: (_) => search(),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: store.status,
        isExpanded: true,
        decoration: const InputDecoration(labelText: '工单状态'),
        items: [
          const DropdownMenuItem(value: '', child: Text('全部状态')),
          ...contract
              .list('states')
              .map(
                (s) => DropdownMenuItem(
                  value: text(s, 'value'),
                  child: Text(text(s, 'label')),
                ),
              ),
        ],
        onChanged: store.busy
            ? null
            : (value) {
                store.status = value!;
                store.reload();
              },
      ),
      const SizedBox(height: 20),
      Text(
        '共 ${store.total} 条记录 · 第 ${store.page} / ${store.totalPages == 0 ? 1 : store.totalPages} 页',
      ),
      const SizedBox(height: 12),
      if (store.orders.isEmpty) empty() else orderGrid(),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: store.busy || store.page <= 1
                ? null
                : () => store.reload(targetPage: store.page - 1),
            child: const Text('上一页'),
          ),
          const SizedBox(width: 24),
          TextButton(
            onPressed: store.busy || store.page >= store.totalPages
                ? null
                : () => store.reload(targetPage: store.page + 1),
            child: const Text('下一页'),
          ),
        ],
      ),
    ],
  );
  void search() {
    store.query = query.text.trim();
    store.reload();
  }

  Future<void> openOrder(String id) async {
    Json? order;
    String error = '';
    try {
      order = await store.detail(id);
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    if (store.actor == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          Future<void> reload() async {
            try {
              final value = await store.detail(
                text(order ?? {}, 'id').isEmpty ? id : text(order!, 'id'),
              );
              if (context.mounted)
                update(() {
                  order = value;
                  error = '';
                });
            } catch (e) {
              if (context.mounted) update(() => error = '$e');
            }
          }

          final current = order;
          return AlertDialog(
            title: Text(
              current == null
                  ? '工单详情'
                  : '${current['number']} · ${contract.state(text(current, 'status'))}',
            ),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (current != null) ...[
                      Text(
                        '${current['customer']}\n${current['project']}\n${current['device']}\n${current['description']}',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '应收 ${money(object(current['summary'])['receivableCents'])}　已收 ${money(object(current['summary'])['collectedCents'])}　待收 ${money(object(current['summary'])['remainingCents'])}',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '下一步：${text(object(current['summary']), 'nextTask')}',
                      ),
                      const SizedBox(height: 16),
                      if ((current['allowedActions'] as List).isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (current['allowedActions'] as List).map((
                            type,
                          ) {
                            final action = contract.action('$type');
                            if (action == null) return const SizedBox.shrink();
                            return OutlinedButton(
                              onPressed: store.busy
                                  ? null
                                  : () async {
                                      Json? result;
                                      final defaults = <String, dynamic>{};
                                      if (type == 'quote')
                                        defaults.addAll(
                                          object(current['quote']),
                                        );
                                      if (type == 'remark')
                                        defaults.addAll({
                                          'remark': current['remark'] ?? '',
                                          'customerNote':
                                              current['customerNote'] ?? '',
                                        });
                                      if (type == 'sign_quote')
                                        defaults['quoteVersion'] = object(
                                          current['quote'],
                                        )['version'];
                                      await showWorkbenchForm(
                                        context,
                                        text(action, 'label'),
                                        records(action['fields']),
                                        (payload) async {
                                          result = await store.act(
                                            current,
                                            '$type',
                                            payload,
                                          );
                                        },
                                        defaults: defaults,
                                      );
                                      if (result != null && context.mounted) {
                                        update(() {
                                          order = result;
                                          error = '';
                                        });
                                      }
                                    },
                              child: Text(text(action, 'label')),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 20),
                      ...detailSections(current),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: reload, child: const Text('重新加载')),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      ),
    );
    await store.reload();
  }

  List<Widget> detailSections(Json order) {
    const titles = {
      'quote': '报价约定',
      'documents': '付款资料',
      'cash': '收退款',
      'invoices': '发票',
      'issues': '客户异议',
      'obligations': '责任余项',
      'evidence': '资料与原件',
      'visits': '上门行程',
      'costs': '成本',
      'commissions': '提成',
      'acceptanceRecords': '验收签署记录',
      'events': '办理记录',
    };
    final children = <Widget>[];
    if (text(order, 'customerNote').isNotEmpty)
      children.add(
        panel('对客说明', [SelectableText(text(order, 'customerNote'))]),
      );
    if (text(order, 'remark').isNotEmpty)
      children.add(panel('内部备注', [SelectableText(text(order, 'remark'))]));
    for (final section in titles.entries) {
      final value = order[section.key];
      if (value == null ||
          value is List && value.isEmpty ||
          value is Map && value.isEmpty)
        continue;
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: panel(section.value, [
            if (value is List)
              ...records(value).map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: recordView(row),
                ),
              )
            else
              recordView(object(value)),
          ]),
        ),
      );
    }
    return children;
  }

  Widget recordView(Json record) {
    const labels = {
      'id': '记录编号',
      'version': '版本',
      'amountCents': '金额',
      'prepayCents': '约定预付款',
      'startRequiresPrepayment': '先款开修',
      'description': '说明',
      'warrantyMonths': '质保月数',
      'paymentTerms': '付款方式',
      'validUntil': '有效期',
      'approved': '已批准',
      'signed': '已签署',
      'autoAccept': '到期自动验收',
      'requirement': '资料要求',
      'reason': '原因',
      'prepared': '已制作',
      'sent': '已发送',
      'recipient': '接收对象',
      'files': '资料原件编号',
      'number': '票号',
      'kind': '类型',
      'purpose': '用途',
      'receipt': '收据凭证',
      'occurredAt': '发生时间',
      'verified': '已核实',
      'handedOver': '已交接',
      'name': '名称',
      'text': '内容',
      'mime': '文件类型',
      'createdAt': '创建时间',
      'title': '事项',
      'ownerId': '责任人',
      'dueAt': '期限',
      'resolved': '已办妥',
      'note': '说明',
      'at': '时间',
      'actorName': '办理人',
      'signerName': '签署人',
      'signedAt': '签署时间',
      'passed': '是否通过',
      'quoteVersion': '报价版本',
      'orderVersion': '工单版本',
      'person': '人员',
      'category': '成本类别',
      'settled': '已结清',
      'plannedAt': '计划时间',
      'feeMemo': '费用说明',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: record.entries
          .where(
            (e) =>
                ![
                  'data',
                  'signature',
                  'deleted',
                  'public',
                  'internal',
                ].contains(e.key) &&
                e.value != null &&
                e.value != '',
          )
          .map((entry) {
            final value = entry.value is bool
                ? (entry.value == true ? '是' : '否')
                : entry.key.endsWith('Cents')
                ? money(entry.value)
                : entry.value is List
                ? (entry.value as List).join('，')
                : '${entry.value}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SelectableText('${labels[entry.key] ?? entry.key}：$value'),
            );
          })
          .toList(),
    );
  }

  Future<void> loan() async {
    await showWorkbenchForm(context, '登记借用', contract.list('loan'), (
      payload,
    ) async {
      await store.write('/loans', payload);
    });
    await store.reload();
  }

  Future<void> purchase() async {
    await showWorkbenchForm(context, '登记采购', contract.list('purchase'), (
      payload,
    ) async {
      await store.write('/purchases', payload);
    });
    await store.reload();
  }

  Widget inventory() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (['admin', 'warehouse'].contains(store.actor?['role']))
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: store.busy ? null : loan,
            child: const Text('登记借用'),
          ),
        ),
      const SizedBox(height: 16),
      Text('库存配件', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (store.parts.isEmpty)
        empty()
      else
        ...store.parts.map(
          (part) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: panel(text(part, 'name'), [
              Text(
                '${part['id']} · ${part['sku']}\n可用 ${part['available']}　待检 ${part['quarantine']}',
              ),
            ]),
          ),
        ),
      const SizedBox(height: 20),
      Text('借还记录', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (store.loans.isEmpty)
        empty()
      else
        ...store.loans.map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: panel('${row['partName']} · ${row['id']}', [
              Text(
                '责任人 ${row['borrowerId']} · 借用 ${row['quantity']} · 尚欠 ${row['outstanding']}\n期限 ${row['dueAt']}',
              ),
              const SizedBox(height: 12),
              if (['admin', 'warehouse'].contains(store.actor?['role']))
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: contract
                      .list('loanActions')
                      .where(
                        (a) =>
                            store.actor?['role'] == 'admin' ||
                            a['type'] == 'return',
                      )
                      .map(
                        (action) => OutlinedButton(
                          onPressed: store.busy
                              ? null
                              : () async {
                                  await showWorkbenchForm(
                                    context,
                                    text(action, 'label'),
                                    records(action['fields']),
                                    (payload) async {
                                      await store.write(
                                        '/loans/${row['id']}/actions',
                                        {
                                          'type': action['type'],
                                          'version': row['version'],
                                          'payload': payload,
                                        },
                                      );
                                    },
                                  );
                                  await store.reload();
                                },
                          child: Text(text(action, 'label')),
                        ),
                      )
                      .toList(),
                ),
            ]),
          ),
        ),
    ],
  );
  Widget purchases() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (['admin', 'warehouse', 'dispatcher'].contains(store.actor?['role']))
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: store.busy ? null : purchase,
            child: const Text('登记采购'),
          ),
        ),
      const SizedBox(height: 16),
      if (store.purchases.isEmpty)
        empty()
      else
        ...store.purchases.map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: panel('${row['id']} · ${row['supplier']}', [
              Text(
                '配件 ${row['partId']} · 数量 ${row['quantity']} · 已收 ${row['received']}\n单价 ${money(row['unitCents'])}',
              ),
              const SizedBox(height: 12),
              if (['admin', 'warehouse'].contains(store.actor?['role']))
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: store.busy
                        ? null
                        : () async {
                            await showWorkbenchForm(
                              context,
                              '分批收货',
                              contract.list('receivePurchase'),
                              (payload) async {
                                await store.write(
                                  '/purchases/${row['id']}/receive',
                                  {'version': row['version'], ...payload},
                                );
                              },
                            );
                            await store.reload();
                          },
                    child: const Text('分批收货'),
                  ),
                ),
            ]),
          ),
        ),
    ],
  );
  Future<void> export() async {
    try {
      final data = await store.exportData();
      final content = const JsonEncoder.withIndent('  ').convert(data);
      await FilePicker.platform.saveFile(
        dialogTitle: '保存授权数据',
        fileName: '维修授权数据.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(content)),
      );
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已打开授权数据保存，请查看下载或所选位置。')));
    } catch (e) {
      showError(e);
    }
  }

  Future<void> showAccounts() async {
    List<Json> rows = [];
    String error = '';
    try {
      rows = await store.accounts();
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          Future<void> load() async {
            try {
              final next = await store.accounts();
              if (context.mounted)
                update(() {
                  rows = next;
                  error = '';
                });
            } catch (e) {
              if (context.mounted) update(() => error = '$e');
            }
          }

          return AlertDialog(
            title: const Text('账号管理'),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error.isNotEmpty) Text(error),
                    if (rows.isEmpty) const Text('暂时没有可显示账号，请连接服务端后重新加载。'),
                    ...rows.map(
                      (row) => ListTile(
                        title: Text('${row['name']} · ${row['username']}'),
                        subtitle: Text('${row['role']} · ${row['status']}'),
                        trailing: OutlinedButton(
                          onPressed: row['id'] == store.actor?['id']
                              ? null
                              : () async {
                                  await showWorkbenchForm(
                                    context,
                                    row['status'] == 'active' ? '停用账号' : '启用账号',
                                    [
                                      {
                                        'key': 'reason',
                                        'label': '变更原因',
                                        'type': 'textarea',
                                        'required': true,
                                      },
                                    ],
                                    (payload) async {
                                      await store.setAccountStatus(
                                        text(row, 'id'),
                                        row['status'] == 'active'
                                            ? 'disabled'
                                            : 'active',
                                        text(payload, 'reason'),
                                      );
                                    },
                                  );
                                  await load();
                                },
                          child: Text(row['status'] == 'active' ? '停用' : '启用'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: load, child: const Text('重新加载')),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> showAudit() async {
    Json result = {};
    String error = '';
    int page = 1;
    try {
      result = await store.audit(page);
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          Future<void> load(int target) async {
            try {
              final value = await store.audit(target);
              if (context.mounted)
                update(() {
                  result = value;
                  page = target;
                  error = '';
                });
            } catch (e) {
              if (context.mounted) update(() => error = '$e');
            }
          }

          return AlertDialog(
            title: Text('审计日志 · 第$page页'),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error.isNotEmpty) Text(error),
                    if (result['items'] is List)
                      ...records(result['items']).map(recordView),
                    if (result['items'] == null ||
                        (result['items'] as List).isEmpty)
                      const Text('暂时没有记录，请重新加载。'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => load(page),
                child: const Text('重新加载'),
              ),
              TextButton(
                onPressed: page > 1 ? () => load(page - 1) : null,
                child: const Text('上一页'),
              ),
              TextButton(
                onPressed: integer(result, 'total') > page * 30
                    ? () => load(page + 1)
                    : null,
                child: const Text('下一页'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> editCompany() async {
    const labels = {
      'companyAddress': '公司地址',
      'companyReceiver': '接收人',
      'companyPhone': '电话',
      'reminderHours': '提醒小时',
      'remarkLimit': '备注字数',
    };
    await showWorkbenchForm(
      context,
      '公司寄送信息',
      labels.entries
          .map(
            (entry) => {
              'key': entry.key,
              'label': entry.value,
              'type': ['reminderHours', 'remarkLimit'].contains(entry.key)
                  ? 'int'
                  : 'text',
              'required': true,
              'value':
                  store.settings[entry.key] ??
                  (entry.key == 'reminderHours'
                      ? 24
                      : entry.key == 'remarkLimit'
                      ? 2000
                      : ''),
            },
          )
          .toList(),
      (payload) async {
        await store.write('/settings', payload);
      },
    );
    await store.reload();
  }

  Future<void> themeForm() async {
    await showWorkbenchForm(
      context,
      '显示主题',
      [
        {
          'key': 'theme',
          'label': '主题',
          'type': 'select',
          'value': widget.mode.name,
          'options': [
            {'value': 'system', 'label': '跟随系统'},
            {'value': 'light', 'label': '浅色'},
            {'value': 'dark', 'label': '深色'},
          ],
        },
      ],
      (payload) async {
        widget.onTheme(
          ThemeMode.values.firstWhere((m) => m.name == payload['theme']),
        );
      },
    );
  }

  Widget adminSettings() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      panel('服务环境', [
        Text(
          '测试地址与线上地址分别保存；切换后清除会话并重新登录。',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(onPressed: configure, child: const Text('切换服务地址')),
            OutlinedButton(onPressed: themeForm, child: const Text('显示主题')),
          ],
        ),
        const SizedBox(height: 16),
        Text('当前：${store.endpoint.isEmpty ? '当前服务' : store.endpoint}'),
      ]),
      const SizedBox(height: 16),
      panel('公司寄送信息', [
        ...const {
          'companyAddress': '公司地址',
          'companyReceiver': '接收人',
          'companyPhone': '联系电话',
          'reminderHours': '提醒小时',
          'remarkLimit': '备注字数',
          'demo': '演示环境',
        }.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(child: Text('${store.settings[entry.key] ?? ''}')),
              ],
            ),
          ),
        ),
        if (store.actor?['role'] == 'admin')
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: store.busy ? null : editCompany,
              child: const Text('修改设置'),
            ),
          ),
      ]),
      const SizedBox(height: 16),
      panel('账号与审计', [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (store.actor?['role'] == 'admin')
              OutlinedButton(
                onPressed: store.busy ? null : showAccounts,
                child: const Text('账号管理'),
              ),
            if (store.actor?['role'] == 'admin')
              OutlinedButton(
                onPressed: store.busy ? null : showAudit,
                child: const Text('审计记录'),
              ),
            if ([
              'admin',
              'dispatcher',
              'finance',
              'customer',
            ].contains(store.actor?['role']))
              OutlinedButton(
                onPressed: store.busy ? null : export,
                child: const Text('导出授权数据'),
              ),
          ],
        ),
      ]),
    ],
  );
  Widget settings() => widget.admin
      ? adminSettings()
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (store.actor?['role'] == 'admin')
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: panel('管理工具', [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: store.busy ? null : showAccounts,
                        child: const Text('账号管理'),
                      ),
                      OutlinedButton(
                        onPressed: store.busy ? null : showAudit,
                        child: const Text('审计日志'),
                      ),
                    ],
                  ),
                ]),
              ),
            panel('服务与账号', [
              Text(
                '当前账号：${store.actor?['name']} (${store.actor?['role']})\n服务地址：${store.endpoint.isEmpty ? '当前网页同源' : store.endpoint}\n请求超时：${store.timeout.inMilliseconds / 1000} 秒\n当前来源：${store.synthetic ? '独立合成演示' : '服务端数据'}',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: configure,
                    child: const Text('设置服务地址'),
                  ),
                  if ([
                    'admin',
                    'dispatcher',
                    'finance',
                    'customer',
                  ].contains(store.actor?['role']))
                    OutlinedButton(
                      onPressed: store.busy ? null : export,
                      child: const Text('导出授权数据'),
                    ),
                ],
              ),
            ]),
            const SizedBox(height: 16),
            panel('显示主题', [
              DropdownButtonFormField<ThemeMode>(
                initialValue: widget.mode,
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('跟随系统'),
                  ),
                  DropdownMenuItem(value: ThemeMode.light, child: Text('白天')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('黑夜')),
                ],
                onChanged: (v) => widget.onTheme(v!),
              ),
            ]),
            const SizedBox(height: 16),
            panel('寄修联系信息', [
              Text(
                '${store.settings['companyAddress'] ?? ''}\n${store.settings['companyReceiver'] ?? ''}　${store.settings['companyPhone'] ?? ''}',
              ),
            ]),
            const SizedBox(height: 16),
            panel('使用提示', [
              const Text(
                '服务端返回成功后才确认真实业务保存。写入超时请保留表单并原内容重试；401请重新登录。独立演示使用另外一份合成台账，后续成功连接服务会自动替换，演示改动不会同步到真实业务。\n\n金额以元填写，最多两位小数；各类编号可从工单详情复制。签署报价和验收需要在签名框手写。实际扣款渠道未接入，收款登记只记录业务事实。',
              ),
            ]),
          ],
        );
  Widget content() {
    switch (view) {
      case 'orders':
        return orders();
      case 'inventory':
        return inventory();
      case 'purchases':
        return purchases();
      case 'settings':
        return settings();
      default:
        return overview();
    }
  }

  Widget nav(bool wide) {
    final buttons = navigation
        .map(
          (item) => Padding(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 16 : 0,
              vertical: 4,
            ),
            child: TextButton(
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                backgroundColor: view == item['id']
                    ? const Color(0xFF0F766E)
                    : Colors.transparent,
                foregroundColor: view == item['id']
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () => setState(() => view = text(item, 'id')),
              child: Text(text(item, 'label')),
            ),
          ),
        )
        .toList();
    return wide
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: buttons,
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: buttons),
          );
  }

  Widget header() => LayoutBuilder(
    builder: (context, size) {
      final title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            navigation.firstWhere(
                  (n) => n['id'] == view,
                  orElse: () => navigation.first,
                )['label']
                as String,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(
                '${store.actor?['name']} ·',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              badge(store.synthetic ? '独立合成演示' : '服务端数据'),
            ],
          ),
        ],
      );
      final actions = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: store.busy ? null : () => store.reload(),
            child: const Text('重新加载'),
          ),
          if (canCreate())
            FilledButton(
              onPressed: store.busy ? null : create,
              child: const Text('新建工单'),
            ),
          OutlinedButton(
            onPressed: () => store.logout(),
            child: const Text('退出'),
          ),
        ],
      );
      return size.maxWidth >= 700
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, actions],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 16), actions],
            );
    },
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final wide = size.maxWidth >= 900;
      final brandPanel = Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text(contract.data, 'brand'),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              widget.admin ? '管理工作台' : '维修服务',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
      if (store.actor == null && widget.admin)
        return Scaffold(body: adminLogin());
      if (store.actor == null)
        return Scaffold(
          appBar: AppBar(
            title: brand(),
            actions: [
              TextButton(onPressed: configure, child: const Text('服务地址')),
            ],
          ),
          body: login(),
        );
      final workspace = Padding(
        padding: EdgeInsets.all(wide ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header(),
            const SizedBox(height: 24),
            if (store.busy) const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => store.reload(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: content(),
                ),
              ),
            ),
          ],
        ),
      );
      return Scaffold(
        body: SafeArea(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 224,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          right: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [brandPanel, nav(true)],
                      ),
                    ),
                    Expanded(child: workspace),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: Theme.of(context).colorScheme.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          brandPanel,
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: nav(false),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: workspace),
                  ],
                ),
        ),
      );
    },
  );
}
