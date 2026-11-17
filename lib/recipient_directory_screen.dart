import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'entry_widgets.dart';
import 'phone_input.dart';
import 'recipient_directory.dart';
import 'recipient_photo.dart';

class RecipientDirectoryScreen extends StatefulWidget {
  const RecipientDirectoryScreen({super.key, required this.directory, this.photoStore});
  final RecipientDirectory directory;
  final RecipientPhotoStore? photoStore;
  @override
  State<RecipientDirectoryScreen> createState() => _RecipientDirectoryScreenState();
}

class _RecipientDirectoryScreenState extends State<RecipientDirectoryScreen> {
  late final _photos = widget.photoStore ?? RecipientPhotoStore();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverPhoto());
  }
  Future<void> _recoverPhoto() async {
    try {
      final path = await _photos.recover();
      if (path == null) return;
      if (!mounted) { await _photos.discard(path); return; }
      final saved = await showDialog<bool>(barrierDismissible: false, context: context, builder: (_) => _RecipientForm(
        directory: widget.directory, photoStore: _photos, recoveredPhoto: path));
      if (saved == true && mounted) setState(() {});
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось восстановить выбранное фото.')));
    }
  }
  Future<void> _edit([DemoRecipient? recipient]) async {
    final saved = await showDialog<bool>(barrierDismissible: false, context: context, builder: (_) => _RecipientForm(
      directory: widget.directory, recipient: recipient, photoStore: _photos));
    if (saved == true && mounted) setState(() {});
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Получатели')),
    floatingActionButton: FloatingActionButton.extended(key: const Key('add_directory_recipient'),
      onPressed: _edit, icon: const Icon(Icons.add), label: const Text('Добавить')),
    body: SafeArea(child: widget.directory.entries.isEmpty
      ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text(
        'База пока пуста. Добавьте телефон и имя получателя.', textAlign: TextAlign.center)))
      : ListView.builder(padding: const EdgeInsets.only(bottom: 90), itemCount: widget.directory.entries.length,
        itemBuilder: (_, index) {
          final recipient = widget.directory.entries[index];
          return ListTile(key: Key('directory_${recipient.phone}'), title: Text(recipient.name),
            leading: RecipientPhoto(path: recipient.photoPath),
            subtitle: Text(formatDemoPhone(recipient.phone)), trailing: const Icon(Icons.edit_outlined),
            onTap: () => _edit(recipient));
        })),
  );
}

class _RecipientForm extends StatefulWidget {
  const _RecipientForm({required this.directory, required this.photoStore, this.recipient, this.recoveredPhoto});
  final RecipientDirectory directory;
  final DemoRecipient? recipient;
  final RecipientPhotoStore photoStore;
  final String? recoveredPhoto;
  @override
  State<_RecipientForm> createState() => _RecipientFormState();
}

class _RecipientFormState extends State<_RecipientForm> {
  final _form = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: formatDemoPhone(widget.recipient?.phone ?? ''));
  late final _name = TextEditingController(text: widget.recipient?.name ?? '');
  late final _card = TextEditingController(text: formatDemoCard(widget.recipient?.card ?? ''));
  bool _saving = false;
  bool _picking = false;
  bool _committed = false;
  late String _photoPath = widget.recoveredPhoto ?? widget.recipient?.photoPath ?? '';
  late final List<String> _newPhotos = [if (widget.recoveredPhoto != null) widget.recoveredPhoto!];
  String? _error;
  @override
  void dispose() {
    for (final path in _newPhotos) {
      if (!_committed || path != _photoPath) unawaited(widget.photoStore.discard(path));
    }
    _phone.dispose(); _name.dispose(); _card.dispose(); super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_picking || _saving) return;
    setState(() { _picking = true; _error = null; });
    try {
      final path = await widget.photoStore.pick();
      if (path == null) return;
      if (!mounted) { await widget.photoStore.discard(path); return; }
      setState(() { _photoPath = path; _newPhotos.add(path); });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on PlatformException {
      if (mounted) setState(() => _error = 'Не удалось открыть выбор фото.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось загрузить фото.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _picking || !_form.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await widget.directory.save(DemoRecipient(phone: _phone.text, name: _name.text, card: _card.text, photoPath: _photoPath),
        previousPhone: widget.recipient?.phone);
      if (mounted) { _committed = true; Navigator.pop(context, true); }
    } on FormatException catch (error) {
      if (mounted) setState(() { _saving = false; _error = error.message; });
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = 'Не удалось сохранить запись. Попробуйте ещё раз.'; });
    }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_saving && !_picking, child: AlertDialog(
    title: Text(widget.recipient == null ? 'Добавить получателя' : 'Изменить получателя'),
    content: SizedBox(width: 340, child: SingleChildScrollView(child: Form(key: _form,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.only(bottom: 8),
          child: RecipientPhoto(path: _photoPath, size: 72)),
        OutlinedButton.icon(key: const Key('pick_recipient_photo'), onPressed: _picking || _saving ? null : _pickPhoto,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(_picking ? 'Загрузка…' : _photoPath.isEmpty ? 'Загрузить фото' : 'Заменить фото')),
        if (_photoPath.isNotEmpty) TextButton(key: const Key('remove_recipient_photo'),
          onPressed: _picking || _saving ? null : () => setState(() => _photoPath = ''), child: const Text('Убрать фото')),
        const SizedBox(height: 12),
        TextFormField(key: const Key('directory_phone'), controller: _phone, keyboardType: TextInputType.phone,
          inputFormatters: [DemoPhoneFormatter()], decoration: const InputDecoration(labelText: 'Телефон'),
          validator: (value) => phoneDirectoryKey(value ?? '') == null ? 'Введите полный номер +7' : null),
        const SizedBox(height: 16),
        TextFormField(key: const Key('directory_name'), controller: _name, maxLength: 50,
          textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Имя получателя'),
          validator: (value) => value == null || value.trim().isEmpty ? 'Введите имя получателя' : null),
        TextFormField(key: const Key('directory_card'), controller: _card, keyboardType: TextInputType.number,
          inputFormatters: [DemoCardFormatter()], decoration: const InputDecoration(labelText: 'Карта (необязательно)'),
          validator: (value) => value!.isNotEmpty && value.replaceAll(RegExp(r'\D'), '').length != 16
            ? 'Введите 16 цифр или оставьте поле пустым' : null),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ])))),
    actions: [TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Отмена')),
      TextButton(key: const Key('save_directory_recipient'), onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Сохранение…' : 'Сохранить'))],
  ));
}
