const mongoose = require('mongoose');
const { Schema } = mongoose;

const AdminSchema = new Schema({
  name: String,
  email: { type: String, unique: true, lowercase: true },
  password_hash: String,
}, { timestamps: true });

const MemberSchema = new Schema({
  name: String,
  email: { type: String, unique: true, lowercase: true },
  phone: String,
  password_hash: String,
  status: { type: String, default: 'active' },
  created_by: { type: Schema.Types.ObjectId, ref: 'Admin' },
}, { timestamps: true });

const DevoteeSchema = new Schema({
  member_id: { type: Schema.Types.ObjectId, ref: 'Member' },
  name: String,
  address: String,
  phone: String,
  initial_payment: { type: Number, default: 0 },
  payment_method: { type: String, default: 'cash' },
  total_amount: { type: Number, default: 0 },
  paid_amount: { type: Number, default: 0 },
  status: { type: String, default: 'pending' },
}, { timestamps: true });

const DonationSchema = new Schema({
  member_id: { type: Schema.Types.ObjectId, ref: 'Member' },
  donor_name: String,
  donor_phone: String,
  section: String,
  description: String,
  amount: { type: Number, default: 0 },
  payment_method: { type: String, default: 'cash' },
  paid: { type: Boolean, default: true },
  donation_date: { type: Date, default: Date.now },
}, { timestamps: true });

const BannerSchema = new Schema({
  member_id: { type: Schema.Types.ObjectId, ref: 'Member' },
  title: String,
  image_url: String,
  description: String,
  start_date: String,
  end_date: String,
  start_time: String,
  end_time: String,
  active: { type: Boolean, default: true },
}, { timestamps: true });

const PoojaBookingSchema = new Schema({
  member_id: { type: Schema.Types.ObjectId, ref: 'Member' },
  devotee_name: String,
  phone: String,
  pooja_name: String,
  booking_date: String,
  booking_time: String,
  amount: { type: Number, default: 0 },
  payment_method: { type: String, default: 'cash' },
  status: { type: String, default: 'booked' },
}, { timestamps: true });

const SankalpBookingSchema = new Schema({
  member_id: { type: Schema.Types.ObjectId, ref: 'Member' },
  devotee_name: String,
  phone: String,
  sankalp_type: String,
  booking_date: String,
  booking_time: String,
  amount: { type: Number, default: 0 },
  payment_method: { type: String, default: 'cash' },
  status: { type: String, default: 'booked' },
}, { timestamps: true });

const MeetingItemSchema = new Schema({
  item_name: String,
  item_type: String,
  quantity: String,
  notes: String,
});

const MeetingSchema = new Schema({
  member_id: { type: Schema.Types.ObjectId, ref: 'Member' },
  title: String,
  meeting_date: String,
  meeting_time: String,
  notes: String,
  items: [MeetingItemSchema],
}, { timestamps: true });

module.exports = {
  Admin: mongoose.model('Admin', AdminSchema),
  Member: mongoose.model('Member', MemberSchema),
  Devotee: mongoose.model('Devotee', DevoteeSchema),
  Donation: mongoose.model('Donation', DonationSchema),
  Banner: mongoose.model('Banner', BannerSchema),
  PoojaBooking: mongoose.model('PoojaBooking', PoojaBookingSchema),
  SankalpBooking: mongoose.model('SankalpBooking', SankalpBookingSchema),
  Meeting: mongoose.model('Meeting', MeetingSchema),
};
