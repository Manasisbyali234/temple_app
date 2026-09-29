import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class MemberDetailScreen extends StatefulWidget {
  final String memberId;
  final String memberName;
  const MemberDetailScreen({super.key, required this.memberId, required this.memberName});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<AuthProvider>().api;
    try {
      final res = await api.get('/members/${widget.memberId}/summary');
      setState(() => _data = res as Map<String, dynamic>);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Failed to load member details.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleStatus() async {
    final currentStatus = _data!['member']['status'];
    final newStatus = currentStatus == 'active' ? 'inactive' : 'active';
    final api = context.read<AuthProvider>().api;
    try {
      await api.patch('/members/${widget.memberId}/status', {'status': newStatus});
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update status')));
      }
    }
  }

  String _fmt(dynamic v) {
    final n = double.tryParse(v?.toString() ?? '0') ?? 0;
    return '₹${n.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.memberName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: DefaultTabController(
                    length: 4,
                    child: Column(
                      children: [
                        _buildHeader(),
                        const TabBar(
                          isScrollable: true,
                          tabs: [
                            Tab(text: 'Devotees'),
                            Tab(text: 'Donations'),
                            Tab(text: 'Pooja'),
                            Tab(text: 'Ana Sankalp'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildDevoteeList(),
                              _buildDonationList(),
                              _buildBookingList(_data!['pooja_bookings'], 'pooja_name'),
                              _buildBookingList(_data!['sankalp_bookings'], 'sankalp_type'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    final member = _data!['member'];
    final totals = _data!['totals'];
    final isActive = member['status'] == 'active';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${member['email']}  •  ${member['phone']}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              Chip(
                label: Text(isActive ? 'Active' : 'Inactive'),
                backgroundColor: isActive ? Colors.green.shade100 : Colors.grey.shade300,
              ),
              TextButton(onPressed: _toggleStatus, child: Text(isActive ? 'Deactivate' : 'Activate')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statTile('Total Collection', _fmt(totals['total_collection']), Colors.green),
              ),
              Expanded(
                child: _statTile('Outstanding', _fmt(totals['total_outstanding']), Colors.orange),
              ),
              Expanded(
                child: _statTile('Devotees', totals['devotee_count'].toString(), Colors.blue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildDevoteeList() {
    final list = _data!['devotees'] as List;
    if (list.isEmpty) return const Center(child: Text('No devotees added yet.'));
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) {
        final d = list[i];
        final status = d['status'];
        return ListTile(
          title: Text(d['name']),
          subtitle: Text('${d['phone'] ?? ''}\nPaid: ${_fmt(d['paid_amount'])} / ${_fmt(d['total_amount'])}'),
          isThreeLine: true,
          trailing: Chip(
            label: Text(status),
            backgroundColor: status == 'paid'
                ? Colors.green.shade100
                : status == 'partially_paid'
                    ? Colors.orange.shade100
                    : Colors.grey.shade300,
          ),
        );
      },
    );
  }

  Widget _buildDonationList() {
    final list = _data!['donations'] as List;
    if (list.isEmpty) return const Center(child: Text('No donations recorded yet.'));
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) {
        final d = list[i];
        return ListTile(
          leading: CircleAvatar(child: Text(d['section'][0].toUpperCase())),
          title: Text('${d['donor_name']} — ${d['section']}'),
          subtitle: Text(d['description'] ?? ''),
          trailing: Text(_fmt(d['amount'])),
        );
      },
    );
  }

  Widget _buildBookingList(List bookings, String nameKey) {
    if (bookings.isEmpty) return const Center(child: Text('No bookings yet.'));
    return ListView.builder(
      itemCount: bookings.length,
      itemBuilder: (_, i) {
        final b = bookings[i];
        return ListTile(
          title: Text('${b['devotee_name']} — ${b[nameKey]}'),
          subtitle: Text('${b['booking_date']}  ${b['booking_time'] ?? ''}'),
          trailing: Text(_fmt(b['amount'])),
        );
      },
    );
  }
}
