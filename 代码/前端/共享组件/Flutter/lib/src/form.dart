import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'contract.dart';
import 'localization.dart';

Future<Json?> showWorkbenchForm(
  BuildContext context,
  String title,
  List<Json> fields,
  Future<void> Function(Json) submit, {
  Json defaults = const {},
}) => showDialog<Json>(
  context: context,
  barrierDismissible: false,
  builder: (_) => WorkbenchForm(
    title: title,
    fields: fields,
    defaults: defaults,
    submit: submit,
  ),
);

// 数字日期选择复用十语字典，避免系统控件缺少藏文时退回英文。
Future<DateTime?> showWorkbenchDateTimePicker(
  BuildContext context,
  DateTime initial,
) {
  var year = initial.year.clamp(2000, 2100).toInt(), month = initial.month;
  var day = initial.day, hour = initial.hour, minute = initial.minute;
  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, update) {
        void change(VoidCallback mutate) => update(() {
          mutate();
          final maximum = DateTime(year, month + 1, 0).day;
          if (day > maximum) day = maximum;
        });

        Widget part(
          String label,
          int value,
          int first,
          int last,
          ValueChanged<int> onChanged,
        ) => DropdownButtonFormField<int>(
          key: ValueKey('date-$label-$value'),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: workbenchText(context, label)),
          items: List.generate(last - first + 1, (index) {
            final number = first + index;
            return DropdownMenuItem(
              value: number,
              child: WorkbenchText('$number'),
            );
          }),
          onChanged: (value) {
            if (value != null) change(() => onChanged(value));
          },
        );

        return AlertDialog(
          title: const WorkbenchText('选择时间'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 12,
                  runSpacing: 18,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth,
                      child: part('年', year, 2000, 2100, (v) => year = v),
                    ),
                    for (final field in <Widget>[
                      part('月', month, 1, 12, (v) => month = v),
                      part(
                        '日',
                        day,
                        1,
                        DateTime(year, month + 1, 0).day,
                        (v) => day = v,
                      ),
                      part('小时', hour, 0, 23, (v) => hour = v),
                      part('分钟', minute, 0, 59, (v) => minute = v),
                    ])
                      SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: field,
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const WorkbenchText('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                DateTime(year, month, day, hour, minute),
              ),
              child: const WorkbenchText('确认提交'),
            ),
          ],
        );
      },
    ),
  );
}

class WorkbenchForm extends StatefulWidget {
  const WorkbenchForm({
    super.key,
    required this.title,
    required this.fields,
    required this.submit,
    this.defaults = const {},
  });
  final String title;
  final List<Json> fields;
  final Json defaults;
  final Future<void> Function(Json) submit;
  @override
  State<WorkbenchForm> createState() => _WorkbenchFormState();
}

class _WorkbenchFormState extends State<WorkbenchForm> {
  final form = GlobalKey<FormState>();
  final Map<String, TextEditingController> controllers = {};
  final Map<String, Object?> values = {};
  bool busy = false;
  String error = '';
  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      final key = text(field, 'key'), type = text(field, 'type');
      Object? value = widget.defaults.containsKey(key)
          ? widget.defaults[key]
          : field['value'];
      if (type == 'datetime' && (value == null || value == ''))
        value = DateTime.now()
            .add(
              Duration(
                days: key == 'deliveredAt' || key == 'occurredAt' ? 0 : 3,
              ),
            )
            .toIso8601String();
      if (type == 'bool' ||
          type == 'select' ||
          type == 'signature' ||
          type == 'file') {
        values[key] = value;
      } else {
        controllers[key] = TextEditingController(
          text: type == 'money' && widget.defaults.containsKey(key)
              ? ((value as num) / 100).toStringAsFixed(2)
              : value is List
              ? value.join(',')
              : value?.toString() ?? '',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy || form.currentState?.validate() != true) return;
    final payload = <String, dynamic>{};
    try {
      for (final field in widget.fields) {
        final key = text(field, 'key'),
            type = text(field, 'type'),
            raw = controllers[key]?.text.trim() ?? '';
        switch (type) {
          case 'bool':
            payload[key] = values[key] == true;
          case 'select':
            payload[key] = values[key];
          case 'int':
            payload[key] = int.parse(raw);
          case 'money':
            payload[key] = (double.parse(raw) * 100).round();
          case 'datetime':
            payload[key] = DateTime.parse(raw).toUtc().toIso8601String();
          case 'list':
            payload[key] = raw
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          case 'signature':
            final strokes = values[key];
            if (strokes is! List<List<Offset>> ||
                strokes.fold<int>(0, (n, s) => n + s.length) < 8)
              throw const FormatException('请在签名框内手写签名');
            payload[key] = await signaturePng(strokes);
          case 'file':
            if (values[key] is Uint8List) {
              payload[key] = base64Encode(values[key] as Uint8List);
            }
          default:
            payload[key] = controllers[key]?.text ?? '';
        }
      }
      setState(() {
        busy = true;
        error = '';
      });
      await widget.submit(payload);
      if (mounted) Navigator.pop(context, payload);
    } catch (e) {
      if (mounted)
        setState(() {
          busy = false;
          error = e.toString();
        });
    }
  }

  Widget fieldWidget(Json field) {
    final key = text(field, 'key'),
        label = text(field, 'label'),
        type = text(field, 'type');
    if (type == 'bool')
      return CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        title: WorkbenchText(label),
        value: values[key] == true,
        onChanged: busy ? null : (v) => setState(() => values[key] = v),
      );
    if (type == 'select')
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          initialValue: values[key] as String?,
          decoration: InputDecoration(labelText: workbenchText(context, label)),
          isExpanded: true,
          items: records(field['options'])
              .map(
                (e) => DropdownMenuItem(
                  value: text(e, 'value'),
                  child: WorkbenchText(text(e, 'label')),
                ),
              )
              .toList(),
          onChanged: busy ? null : (v) => setState(() => values[key] = v),
        ),
      );
    if (type == 'signature')
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WorkbenchText(label),
            const SizedBox(height: 8),
            SignaturePad(onChanged: (strokes) => values[key] = strokes),
          ],
        ),
      );
    if (type == 'file')
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: OutlinedButton(
          onPressed: busy
              ? null
              : () async {
                  final result = await FilePicker.platform.pickFiles(
                    withData: true,
                  );
                  if (result == null || !mounted) return;
                  final file = result.files.single;
                  if (file.size > 8 * 1024 * 1024) {
                    setState(() => error = '文件请控制在8MB以内');
                    return;
                  }
                  if (file.bytes == null) {
                    setState(() => error = '无法读取该文件，请重新选择');
                    return;
                  }
                  setState(() {
                    values[key] = file.bytes;
                    if (controllers['name']?.text.isEmpty == true)
                      controllers['name']!.text = file.name;
                    const mime = {
                      'pdf': 'application/pdf',
                      'png': 'image/png',
                      'jpg': 'image/jpeg',
                      'jpeg': 'image/jpeg',
                      'txt': 'text/plain',
                      'mp4': 'video/mp4',
                      'mp3': 'audio/mpeg',
                    };
                    if (controllers['mime'] != null)
                      controllers['mime']!.text =
                          mime[file.extension?.toLowerCase()] ??
                          'application/octet-stream';
                  });
                },
          child: WorkbenchText(
            values[key] is Uint8List
                ? '已选文件（${(values[key] as Uint8List).length}字节），点此替换'
                : '选择本地文件（最多8MB）',
          ),
        ),
      );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controllers[key],
        enabled: !busy,
        decoration: InputDecoration(
          labelText: workbenchText(context, label),
          suffixIcon: type == 'datetime'
              ? TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final initial =
                              DateTime.tryParse(controllers[key]!.text) ??
                              DateTime.now();
                          final selected = await showWorkbenchDateTimePicker(
                            context,
                            initial,
                          );
                          if (selected == null || !mounted) return;
                          controllers[key]!.text = selected.toIso8601String();
                        },
                  child: const WorkbenchText('选择时间'),
                )
              : null,
          helperText: type == 'datetime'
              ? workbenchText(context, '格式：2026-10-30T15:30:00+08:00')
              : null,
        ),
        minLines: type == 'textarea' ? 2 : 1,
        maxLines: type == 'textarea' ? 4 : 1,
        keyboardType: ['int', 'money'].contains(type)
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        validator: (value) {
          final raw = value?.trim() ?? '';
          if (field['required'] == true && raw.isEmpty)
            return workbenchText(
              context,
              r'请填写$label',
            ).replaceAll(r'$label', workbenchText(context, label));
          if (type == 'int' && int.tryParse(raw) == null)
            return workbenchText(context, '请输入整数');
          if (type == 'money' &&
              (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(raw) ||
                  double.tryParse(raw) == null))
            return workbenchText(context, '请输入非负金额，最多两位小数');
          if (type == 'datetime' && DateTime.tryParse(raw) == null)
            return workbenchText(context, '请填写有效日期时间');
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: WorkbenchText(widget.title),
    content: SizedBox(
      width: 620,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: WorkbenchText(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ...widget.fields.map(fieldWidget),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const WorkbenchText('取消'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: WorkbenchText(busy ? '正在提交…' : '确认提交'),
      ),
    ],
  );
}

class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, required this.onChanged});
  final ValueChanged<List<List<Offset>>> onChanged;
  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  List<List<Offset>> strokes = [];
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF52636B)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: LayoutBuilder(
          builder: (context, size) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => setState(() {
              strokes.add([
                Offset(
                  (d.localPosition.dx / size.maxWidth).clamp(0, 1),
                  (d.localPosition.dy / 180).clamp(0, 1),
                ),
              ]);
              widget.onChanged(strokes);
            }),
            onPanUpdate: (d) => setState(() {
              if (strokes.isNotEmpty)
                strokes.last.add(
                  Offset(
                    (d.localPosition.dx / size.maxWidth).clamp(0, 1),
                    (d.localPosition.dy / 180).clamp(0, 1),
                  ),
                );
              widget.onChanged(strokes);
            }),
            child: CustomPaint(
              painter: SignaturePainter(strokes),
              size: Size.infinite,
            ),
          ),
        ),
      ),
      TextButton(
        onPressed: () => setState(() {
          strokes = [];
          widget.onChanged(strokes);
        }),
        child: const WorkbenchText('清除签名'),
      ),
    ],
  );
}

class SignaturePainter extends CustomPainter {
  SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF172B35)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final stroke in strokes) {
      for (var i = 1; i < stroke.length; i++) {
        canvas.drawLine(
          Offset(stroke[i - 1].dx * size.width, stroke[i - 1].dy * size.height),
          Offset(stroke[i].dx * size.width, stroke[i].dy * size.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) => true;
}

Future<String> signaturePng(List<List<Offset>> strokes) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(Colors.white, BlendMode.src);
  SignaturePainter(strokes).paint(canvas, const Size(640, 240));
  final picture = recorder.endRecording();
  final image = await picture.toImage(640, 240);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return 'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}';
}
