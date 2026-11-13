import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 展示层翻译与业务原文分离，语言切换不改变字段值或请求。
class WorkbenchTranslations extends ChangeNotifier {
  static final instance = WorkbenchTranslations();
  static const languages = <String, String>{
    'zh-Hans': '简体中文',
    'zh-Hant': '繁體中文',
    'bo': 'བོད་ཡིག',
    'en': 'English',
    'ja': '日本語',
    'fr': 'Français',
    'es': 'Español',
    'de': 'Deutsch',
    'ru': 'Русский',
    'ko': '한국어',
  };

  String locale = 'zh-Hans';
  Map<String, Map<String, String>> _messages = {};
  List<String> _keys = [];

  Future<void> load() async {
    final data =
        jsonDecode(
              await rootBundle.loadString(
                'packages/repair_shared/assets/ui-l10n.json',
              ),
            )
            as Map<String, dynamic>;
    final messages = data['messages'] as Map<String, dynamic>;
    _messages = messages.map(
      (language, values) => MapEntry(
        language,
        (values as Map<String, dynamic>).map(
          (source, value) => MapEntry(source, value.toString()),
        ),
      ),
    );
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString('repair-ui-locale');
    if (languages.containsKey(saved)) locale = saved!;
    _refreshKeys();
    notifyListeners();
  }

  void _refreshKeys() {
    _keys = (_messages[locale]?.keys ?? <String>[]).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
  }

  Future<void> select(String value) async {
    if (!languages.containsKey(value)) return;
    locale = value;
    _refreshKeys();
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('repair-ui-locale', value);
  }

  String text(String source) {
    if (locale == 'zh-Hans') return source;
    final dictionary = _messages[locale] ?? const <String, String>{};
    if (dictionary.containsKey(source)) return dictionary[source]!;
    if (!RegExp(r'[\u3400-\u9fff]').hasMatch(source)) return source;
    // 动态数量、金额和标识仍保持原值，只翻译匹配的界面句段。
    final pattern = _keys
        .where((key) => source.contains(key))
        .map(RegExp.escape);
    if (pattern.isEmpty) return source;
    return source.replaceAllMapped(
      RegExp(pattern.join('|')),
      (match) => dictionary[match[0]] ?? match[0]!,
    );
  }
}

class WorkbenchLocaleScope extends InheritedNotifier<WorkbenchTranslations> {
  WorkbenchLocaleScope({super.key, required super.child})
    : super(notifier: WorkbenchTranslations.instance);

  static WorkbenchTranslations of(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<WorkbenchLocaleScope>();
    return WorkbenchTranslations.instance;
  }
}

String workbenchText(BuildContext context, String source) =>
    WorkbenchLocaleScope.of(context).text(source);

class WorkbenchText extends StatelessWidget {
  const WorkbenchText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.softWrap,
    this.overflow,
    this.translate = true,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool? softWrap;
  final TextOverflow? overflow;
  final bool translate;

  @override
  Widget build(BuildContext context) => Text(
    translate ? workbenchText(context, data) : data,
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    softWrap: softWrap,
    overflow: overflow,
  );
}

class WorkbenchLanguagePicker extends StatelessWidget {
  const WorkbenchLanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final translations = WorkbenchLocaleScope.of(context);
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: translations.locale,
        borderRadius: BorderRadius.circular(10),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        items: WorkbenchTranslations.languages.entries
            .map(
              (language) => DropdownMenuItem(
                value: language.key,
                child: Text(
                  language.value,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) translations.select(value);
        },
      ),
    );
  }
}
