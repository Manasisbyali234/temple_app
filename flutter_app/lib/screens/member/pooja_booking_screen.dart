import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/models.dart';
import '../../widgets/booking_form.dart';

class PoojaBookingScreen extends StatefulWidget {
  const PoojaBookingScreen({super.key});

  @override
  State<PoojaBookingScreen> createState() => _PoojaBookingScreenState();
}

class _PoojaBookingScreenState extends State<PoojaBookingScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<Booking> _bookings = [];
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
      final res = await api.get('/pooja-bookings');
      setState(() =>
          _bookings = (res as List).map((e) => Booking.fromJson(e, typeKey: 'pooja_name')).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _bookings.fold<double>(0, (s, b) => s + b.amount);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pooja Booking'),
        bottom: TabBar(controller: _tab, tabs: const [Tab(text: 'New Booking'), Tab(text: 'All Bookings')]),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          BookingForm(
            endpoint: '/pooja-bookings',
            typeLabel: 'Pooja Name',
            typeKey: 'pooja_name',
            onSaved: _load,
          ),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Text('Total Amount: ₹${total.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: _bookings.isEmpty
                          ? const Center(child: Text('No bookings yet.'))
                          : ListView.builder(
                              itemCount: _bookings.length,
                              itemBuilder: (_, i) {
                                final b = _bookings[i];
                                return ListTile(
                                  leading: const Icon(Icons.local_fire_department, color: Colors.orange),
                                  title: Text('${b.devoteeName} — ${b.typeName}'),
                                  subtitle: Text('${b.bookingDate}  ${b.bookingTime ?? ''}'),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('₹${b.amount.toStringAsFixed(0)}'),
                                      Text(b.status, style: Theme.of(context).textTheme.bodySmall),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}
