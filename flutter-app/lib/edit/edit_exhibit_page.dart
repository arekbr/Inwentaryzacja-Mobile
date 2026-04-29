import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dictionaries/dict_item.dart';
import '../dictionaries/dictionaries_provider.dart';
import '../identify/artefakt.dart';
import 'exhibit_form_state.dart';

class EditExhibitPage extends ConsumerStatefulWidget {
  final Artefakt artefakt;
  final String photoPath;

  const EditExhibitPage({
    super.key,
    required this.artefakt,
    required this.photoPath,
  });

  @override
  ConsumerState<EditExhibitPage> createState() => _EditExhibitPageState();
}

class _EditExhibitPageState extends ConsumerState<EditExhibitPage> {
  late final TextEditingController _name;
  late final TextEditingController _vendor;
  late final TextEditingController _model;
  late final TextEditingController _serial;
  late final TextEditingController _part;
  late final TextEditingController _revision;
  late final TextEditingController _year;
  late final TextEditingController _storage;
  late final TextEditingController _description;
  late final TextEditingController _value;

  late String _type;
  late String _status;
  late bool _hasPackaging;

  String? _validationError;

  @override
  void initState() {
    super.initState();
    final form = ExhibitForm.fromArtefakt(widget.artefakt);
    _name = TextEditingController(text: form.name);
    _vendor = TextEditingController(text: form.vendor);
    _model = TextEditingController(text: form.model);
    _serial = TextEditingController(text: form.serialNumber);
    _part = TextEditingController(text: form.partNumber);
    _revision = TextEditingController(text: form.revision);
    _year = TextEditingController(text: form.productionYear);
    _storage = TextEditingController(text: form.storagePlace);
    _description = TextEditingController(text: form.description);
    _value = TextEditingController(text: form.value);
    _type = form.type;
    _status = form.status;
    _hasPackaging = form.hasOriginalPackaging;
  }

  @override
  void dispose() {
    for (final c in [_name, _vendor, _model, _serial, _part, _revision,
      _year, _storage, _description, _value]) {
      c.dispose();
    }
    super.dispose();
  }

  ExhibitForm _currentForm() => ExhibitForm(
        name: _name.text,
        type: _type,
        vendor: _vendor.text,
        model: _model.text,
        serialNumber: _serial.text,
        partNumber: _part.text,
        revision: _revision.text,
        productionYear: _year.text,
        status: _status,
        storagePlace: _storage.text,
        description: _description.text,
        value: _value.text,
        hasOriginalPackaging: _hasPackaging,
      );

  Future<void> _pickFromList({
    required String title,
    required AsyncValue<List<DictItem>> dictAsync,
    required String current,
    required ValueChanged<String> onPicked,
  }) async {
    final items = dictAsync.asData?.value ?? const <DictItem>[];
    if (items.isEmpty) {
      _showInfo('Brak słownika — backend jeszcze nie odpowiedział.');
      return;
    }
    int initial = items.indexWhere((i) => i.name == current);
    if (initial < 0) initial = 0;

    String picked = items[initial].name;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Anuluj'),
                    ),
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    CupertinoButton(
                      onPressed: () {
                        onPicked(picked);
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Wybierz'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController:
                      FixedExtentScrollController(initialItem: initial),
                  onSelectedItemChanged: (i) => picked = items[i].name,
                  children: [
                    for (final item in items)
                      Center(child: Text(item.name)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfo(String msg) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _onSave() {
    final form = _currentForm();
    final err = form.validate();
    setState(() => _validationError = err);
    if (err != null) return;
    _showInfo('Zapis do bazy w F8 — TODO. Walidacja OK.');
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(typesProvider);
    final vendorsAsync = ref.watch(vendorsProvider);
    final modelsAsync = ref.watch(modelsProvider);
    final statusesAsync = ref.watch(statusesProvider);
    final placesAsync = ref.watch(storagePlacesProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Edytuj eksponat')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(File(widget.photoPath),
                  height: 140, fit: BoxFit.cover, width: double.infinity),
            ),
            const SizedBox(height: 16),
            _label('Nazwa *'),
            _text(_name, 'np. Klawiatura Amiga 500'),
            _label('Typ *'),
            _picker(_type, () => _pickFromList(
                  title: 'Typ',
                  dictAsync: typesAsync,
                  current: _type,
                  onPicked: (v) => setState(() => _type = v),
                )),
            _label('Producent *'),
            _comboField(_vendor, vendorsAsync, 'np. Commodore'),
            _label('Model *'),
            _comboField(_model, modelsAsync, 'np. A500'),
            _label('Status *'),
            _picker(_status, () => _pickFromList(
                  title: 'Status',
                  dictAsync: statusesAsync,
                  current: _status,
                  onPicked: (v) => setState(() => _status = v),
                )),
            _label('Miejsce przechowywania'),
            _comboField(_storage, placesAsync, 'np. Magazyn 3, półka 2'),
            _label('Numer seryjny'),
            _text(_serial, 'opcjonalnie'),
            _label('Part number'),
            _text(_part, 'opcjonalnie'),
            _label('Rewizja'),
            _text(_revision, 'opcjonalnie'),
            _label('Rok produkcji'),
            _text(_year, '1985', keyboardType: TextInputType.number),
            _label('Wartość (PLN)'),
            _text(_value, 'opcjonalnie', keyboardType: TextInputType.number),
            _label('Opis'),
            _text(_description, 'opis eksponatu', maxLines: 5),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Oryginalne opakowanie')),
                CupertinoSwitch(
                  value: _hasPackaging,
                  onChanged: (v) => setState(() => _hasPackaging = v),
                ),
              ],
            ),
            if (_validationError != null) ...[
              const SizedBox(height: 12),
              Text(_validationError!,
                  style: const TextStyle(
                      color: CupertinoColors.destructiveRed, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: _onSave,
              child: const Text('Zapisz do bazy'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12, color: CupertinoColors.systemGrey)),
      );

  Widget _text(TextEditingController c, String hint,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return CupertinoTextField(
      controller: c,
      placeholder: hint,
      maxLines: maxLines,
      keyboardType: keyboardType,
      autocorrect: false,
      padding: const EdgeInsets.all(10),
    );
  }

  Widget _picker(String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? '— wybierz —' : value,
                style: TextStyle(
                  fontSize: 16,
                  color: value.isEmpty
                      ? CupertinoColors.systemGrey
                      : CupertinoColors.label,
                ),
              ),
            ),
            const Icon(CupertinoIcons.chevron_down,
                size: 18, color: CupertinoColors.systemGrey),
          ],
        ),
      ),
    );
  }

  Widget _comboField(
      TextEditingController c, AsyncValue<List<DictItem>> dictAsync, String hint) {
    return Row(
      children: [
        Expanded(child: _text(c, hint)),
        const SizedBox(width: 6),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          onPressed: () => _pickFromList(
            title: 'Wybierz ze słownika',
            dictAsync: dictAsync,
            current: c.text,
            onPicked: (v) => setState(() => c.text = v),
          ),
          child: const Icon(CupertinoIcons.list_bullet, size: 22),
        ),
      ],
    );
  }
}
