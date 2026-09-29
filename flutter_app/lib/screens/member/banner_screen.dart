import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';

class BannerScreen extends StatefulWidget {
  const BannerScreen({super.key});

  @override
  State<BannerScreen> createState() => _BannerScreenState();
}

class _BannerScreenState extends State<BannerScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<BannerAd> _banners = [];
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
      final res = await api.get('/banners');
      setState(() => _banners = (res as List).map((e) => BannerAd.fromJson(e)).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Banner / Advertisement'),
        bottom: TabBar(controller: _tab, tabs: const [Tab(text: 'Create'), Tab(text: 'All Banners')]),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _AddBannerForm(onSaved: _load),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _banners.isEmpty
                  ? const Center(child: Text('No banners yet.'))
                  : ListView.builder(
                      itemCount: _banners.length,
                      itemBuilder: (_, i) {
                        final b = _banners[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: Icon(Icons.campaign, color: b.active ? Colors.green : Colors.grey),
                            title: Text(b.title),
                            subtitle: Text(
                                '${b.startDate} → ${b.endDate}\n${b.startTime ?? ''} - ${b.endTime ?? ''}'),
                            isThreeLine: true,
                            trailing: Chip(label: Text(b.active ? 'Active' : 'Inactive')),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}

class _AddBannerForm extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddBannerForm({required this.onSaved});

  @override
  State<_AddBannerForm> createState() => _AddBannerFormState();
}

class _AddBannerFormState extends State<_AddBannerForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _loading = false;

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => isStart ? _startDate = picked : _endDate = picked);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  String _fmtTime(TimeOfDay? t) => t == null ? 'Select' : t.format(context);
  String _fmtDate(DateTime? d) => d == null ? 'Select' : DateFormat('dd MMM yyyy').format(d);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select start and end date')));
      return;
    }
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      await api.post('/banners', {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'image_url': _imageUrlCtrl.text.trim(),
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
        'start_time': _startTime != null ? '${_startTime!.hour}:${_startTime!.minute}:00' : null,
        'end_time': _endTime != null ? '${_endTime!.hour}:${_endTime!.minute}:00' : null,
      });
      _titleCtrl.clear();
      _descCtrl.clear();
      _imageUrlCtrl.clear();
      setState(() {
        _startDate = null;
        _endDate = null;
        _startTime = null;
        _endTime = null;
      });
      widget.onSaved();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Banner created')));
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
            decoration: const InputDecoration(labelText: 'Banner / Ad Title', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _imageUrlCtrl,
            decoration: const InputDecoration(labelText: 'Image URL (optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text('Start: ${_fmtDate(_startDate)}'),
                  onPressed: () => _pickDate(isStart: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time),
                  label: Text(_fmtTime(_startTime)),
                  onPressed: () => _pickTime(isStart: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text('End: ${_fmtDate(_endDate)}'),
                  onPressed: () => _pickDate(isStart: false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time),
                  label: Text(_fmtTime(_endTime)),
                  onPressed: () => _pickTime(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('Save Banner'),
          ),
        ],
      ),
    );
  }
}
