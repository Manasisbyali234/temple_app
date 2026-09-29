class AuthUser {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;

  AuthUser({required this.id, required this.name, required this.email, this.phone, required this.role});
}

class MemberSummary {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String status;
  final double totalCollection;
  final double totalOutstanding;
  final int devoteeCount;
  final int donationCount;

  MemberSummary({
    required this.id, required this.name, required this.email, required this.phone,
    required this.status, required this.totalCollection, required this.totalOutstanding,
    required this.devoteeCount, required this.donationCount,
  });

  factory MemberSummary.fromJson(Map<String, dynamic> json) => MemberSummary(
    id: (json['id'] ?? json['_id'] ?? '').toString(),
    name: json['name'] ?? '',
    email: json['email'] ?? '',
    phone: json['phone'] ?? '',
    status: json['status'] ?? 'active',
    totalCollection: double.tryParse(json['total_collection'].toString()) ?? 0,
    totalOutstanding: double.tryParse(json['total_outstanding'].toString()) ?? 0,
    devoteeCount: int.tryParse(json['devotee_count'].toString()) ?? 0,
    donationCount: int.tryParse(json['donation_count'].toString()) ?? 0,
  );
}

class Devotee {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final double initialPayment;
  final String paymentMethod;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final String status;
  final DateTime createdAt;

  Devotee({
    required this.id, required this.name, this.address, this.phone,
    required this.initialPayment, required this.paymentMethod,
    required this.totalAmount, required this.paidAmount,
    required this.outstandingAmount, required this.status, required this.createdAt,
  });

  factory Devotee.fromJson(Map<String, dynamic> json) => Devotee(
    id: (json['id'] ?? json['_id'] ?? '').toString(),
    name: json['name'] ?? '',
    address: json['address'],
    phone: json['phone'],
    initialPayment: double.tryParse(json['initial_payment'].toString()) ?? 0,
    paymentMethod: json['payment_method'] ?? 'cash',
    totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0,
    paidAmount: double.tryParse(json['paid_amount'].toString()) ?? 0,
    outstandingAmount: (double.tryParse(json['total_amount'].toString()) ?? 0) -
        (double.tryParse(json['paid_amount'].toString()) ?? 0),
    status: json['status'] ?? 'pending',
    createdAt: DateTime.tryParse(json['createdAt'] ?? json['created_at'] ?? '') ?? DateTime.now(),
  );
}

class Donation {
  final String id;
  final String donorName;
  final String? donorPhone;
  final String section;
  final String? description;
  final double amount;
  final String paymentMethod;
  final bool paid;
  final DateTime donationDate;

  Donation({
    required this.id, required this.donorName, this.donorPhone,
    required this.section, this.description, required this.amount,
    required this.paymentMethod, required this.paid, required this.donationDate,
  });

  factory Donation.fromJson(Map<String, dynamic> json) => Donation(
    id: (json['id'] ?? json['_id'] ?? '').toString(),
    donorName: json['donor_name'] ?? '',
    donorPhone: json['donor_phone'],
    section: json['section'] ?? 'other',
    description: json['description'],
    amount: double.tryParse(json['amount'].toString()) ?? 0,
    paymentMethod: json['payment_method'] ?? 'cash',
    paid: json['paid'] == true,
    donationDate: DateTime.tryParse(json['donation_date'] ?? '') ?? DateTime.now(),
  );
}

class BannerAd {
  final String id;
  final String title;
  final String? imageUrl;
  final String? description;
  final String startDate;
  final String endDate;
  final String? startTime;
  final String? endTime;
  final bool active;

  BannerAd({
    required this.id, required this.title, this.imageUrl, this.description,
    required this.startDate, required this.endDate, this.startTime, this.endTime, required this.active,
  });

  factory BannerAd.fromJson(Map<String, dynamic> json) => BannerAd(
    id: (json['id'] ?? json['_id'] ?? '').toString(),
    title: json['title'] ?? '',
    imageUrl: json['image_url'],
    description: json['description'],
    startDate: json['start_date'] ?? '',
    endDate: json['end_date'] ?? '',
    startTime: json['start_time'],
    endTime: json['end_time'],
    active: json['active'] == true,
  );
}

class Booking {
  final String id;
  final String devoteeName;
  final String? phone;
  final String typeName;
  final String bookingDate;
  final String? bookingTime;
  final double amount;
  final String paymentMethod;
  final String status;

  Booking({
    required this.id, required this.devoteeName, this.phone,
    required this.typeName, required this.bookingDate, this.bookingTime,
    required this.amount, required this.paymentMethod, required this.status,
  });

  factory Booking.fromJson(Map<String, dynamic> json, {required String typeKey}) => Booking(
    id: (json['id'] ?? json['_id'] ?? '').toString(),
    devoteeName: json['devotee_name'] ?? '',
    phone: json['phone'],
    typeName: json[typeKey] ?? '',
    bookingDate: json['booking_date'] ?? '',
    bookingTime: json['booking_time'],
    amount: double.tryParse(json['amount'].toString()) ?? 0,
    paymentMethod: json['payment_method'] ?? 'cash',
    status: json['status'] ?? 'booked',
  );
}

class MeetingItem {
  final String itemName;
  final String? itemType;
  final String? quantity;
  final String? notes;

  MeetingItem({required this.itemName, this.itemType, this.quantity, this.notes});

  Map<String, dynamic> toJson() => {
    'item_name': itemName, 'item_type': itemType, 'quantity': quantity, 'notes': notes,
  };

  factory MeetingItem.fromJson(Map<String, dynamic> json) => MeetingItem(
    itemName: json['item_name'] ?? '',
    itemType: json['item_type'],
    quantity: json['quantity']?.toString(),
    notes: json['notes'],
  );
}

class Meeting {
  final String id;
  final String title;
  final String meetingDate;
  final String? meetingTime;
  final String? notes;
  final List<MeetingItem> items;

  Meeting({
    required this.id, required this.title, required this.meetingDate,
    this.meetingTime, this.notes, required this.items,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
    id: (json['id'] ?? json['_id'] ?? '').toString(),
    title: json['title'] ?? '',
    meetingDate: json['meeting_date'] ?? '',
    meetingTime: json['meeting_time'],
    notes: json['notes'],
    items: (json['items'] as List<dynamic>? ?? [])
        .map((e) => MeetingItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
