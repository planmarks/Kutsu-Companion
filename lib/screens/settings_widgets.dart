import 'package:flutter/material.dart';
import '../theme.dart';

InputDecoration inputDec(KT k, String hint) => InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: k.muted), isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: k.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: k.brand)),
    );

class SettingToggle extends StatelessWidget {
  final String label;
  final String? desc;
  final bool value;
  final ValueChanged<bool> onChanged;
  const SettingToggle({super.key, required this.label, required this.value, required this.onChanged, this.desc});
  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: k.line, width: 0.5))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: k.ink, fontWeight: FontWeight.w600)),
          if (desc != null) Text(desc!, style: TextStyle(color: k.muted, fontSize: 12)),
        ])),
        Switch(value: value, activeColor: k.brand, onChanged: onChanged),
      ]),
    );
  }
}

class SettingOptions extends StatelessWidget {
  final String label;
  final int value;
  final List<String> options;
  final ValueChanged<int> onChanged;
  const SettingOptions({super.key, required this.label, required this.value, required this.options, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: k.line, width: 0.5))),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: k.ink, fontWeight: FontWeight.w600))),
        Flexible(child: Wrap(alignment: WrapAlignment.end, spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < options.length; i++)
            GestureDetector(onTap: () => onChanged(i), child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: i == value ? k.brand : k.chip, borderRadius: BorderRadius.circular(8)),
              child: Text(options[i], style: TextStyle(color: i == value ? Colors.white : k.muted, fontSize: 12, fontWeight: FontWeight.w600)),
            )),
        ])),
      ]),
    );
  }
}
