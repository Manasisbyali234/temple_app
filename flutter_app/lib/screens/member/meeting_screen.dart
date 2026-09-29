import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';

class MeetingScreen extends StatefulWidget {
  const MeetingScreen({super.key});

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<Meeting> _meetings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      final res = await api.get('/meetings');
      setState(() => _meetings = (res as List).map((e) => Meeting.fromJson(e)).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sawal (Meeting)'),
        bottom: TabBar(controller: _tab, tabs: const [Tab(text: 'Schedule Meeting'), Tab(text: 'All Meetings')]),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _MeetingForm(onSaved: _load),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _meetings.isEmpty
                  ? const Center(child: Text('No meetings scheduled yet.'))
                  : ListView.builder(
                      itemCount: _meetings.length,
                      itemBuilder: (_, i) {
                        final m = _meetings[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ExpansionTile(
                            leading: const Icon(Icons.groups_2, color: Colors.teal),
                            title: Text(m.title),
                            subtitle: Text('${m.meetingDate}  ${m.meetingTime ?? ''}'),
                            children: [
                              if (m.notes != null && m.notes!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: Align(alignment: Alignment.centerLeft, child: Text('Notes: ${m.notes}')),
                                ),
                              if (m.items.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('No items required for this meeting.'),
                                )
                              else
                                ...m.items.map((item) => ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.checklist, size: 20),
                                      title: Text(item.itemName),
                                      subtitle: Text(
                                          '${item.itemType ?? ''}${item.quantity != null ? '  •  Qty: ${item.quantity}' : ''}'),
                                    )),
                              const SizedBox(height: 8),
                            ],
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}

class _ItemRow {
  final nameCtrl = TextEditingController();
  final typeCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
}

class _MeetingForm extends StatefulWidget {
  final VoidCallback onSaved;
  const _MeetingForm({required this.onSaved});

  @override
  State<_MeetingForm> createState() => _MeetingFormState();
}

class _MeetingFormState extends State<_MeetingForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  final List<_ItemRow> _items = [_ItemRow()];
  bool _loading = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a meeting date')));
      return;
    }
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      final items = _items
          .where((r) => r.nameCtrl.text.trim().isNotEmpty)
          .map((r) => {
                'item_name': r.nameCtrl.text.trim(),
                'item_type': r.typeCtrl.text.trim(),
                'quantity': r.qtyCtrl.text.trim(),
              })
          .toList();

      await api.post('/meetings', {
        'title': _titleCtrl.text.trim(),
        'meeting_date': DateFormat('yyyy-MM-dd').format(_date!),
        'meeting_time': _time != null ? '${_time!.hour}:${_time!.minute}:00' : null,
        'notes': _notesCtrl.text.trim(),
        'items': items,
      });
      _titleCtrl.clear();
      _notesCtrl.clear();
      setState(() {
        _date = null;
        _time = null;
        _items
          ..clear()
          ..add(_ItemRow());
      });
      widget.onSaved();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meeting scheduled')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Meeting Title', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_date == null ? 'Select Date' : DateFormat('dd MMM yyyy').format(_date!)),
                  onPressed: _pickDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time),
                  label: Text(_time == null ? 'Select Time' : _time!.format(context)),
                  onPressed: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesCtrl,
            decoration: const InputDecoration(labelText: 'Notes / Agenda', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Items Required', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.teal),
                onPressed: () => setState(() => _items.add(_ItemRow())),
              ),
            ],
          ),
          ..._items.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Item ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        if (_items.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => setState(() => _items.removeAt(i)),
                          ),
                      ],
                    ),
                    TextField(
                      controller: row.nameCtrl,
                      decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: row.typeCtrl,
                            decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: row.qtyCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('Save Meeting'),
          ),
        ],
      ),
    );
  }
}
