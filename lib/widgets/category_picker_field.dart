import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'field_decoration.dart';

class CategoryPickerField extends StatelessWidget {
  final String? value;
  final String? errorText;
  final ValueChanged<String> onChanged;

  const CategoryPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Pilih kategori',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            for (final c in kCategories)
              ListTile(
                leading: Icon(categoryIcon(c), color: categoryColor(c)),
                title: Text(c),
                trailing:
                    c == value ? const Icon(Icons.check, color: kPrimary) : null,
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: fieldDecoration('Kategori',
                suffix: const Icon(Icons.arrow_drop_down))
            .copyWith(errorText: errorText),
        child: Text(
          value ?? 'Pilih',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: value == null ? kTextGrey : kTextDark),
        ),
      ),
    );
  }
}
