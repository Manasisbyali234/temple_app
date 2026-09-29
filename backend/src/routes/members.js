const express = require('express');
const bcrypt = require('bcryptjs');
const { Member, Devotee, Donation, PoojaBooking, SankalpBooking } = require('../models');
const { verifyToken, requireAdmin } = require('../middleware/auth');

const router = express.Router();

// GET /api/members/dashboard/admin
router.get('/dashboard/admin', verifyToken, requireAdmin, async (req, res) => {
  try {
    const [members, devotees, donations, pooja, sankalp] = await Promise.all([
      Member.countDocuments(),
      Devotee.find(),
      Donation.find({ paid: true }),
      PoojaBooking.countDocuments(),
      SankalpBooking.countDocuments(),
    ]);
    const total_collection =
      devotees.reduce((s, d) => s + d.paid_amount, 0) +
      donations.reduce((s, d) => s + d.amount, 0);
    const total_outstanding = devotees.reduce((s, d) => s + (d.total_amount - d.paid_amount), 0);
    res.json({
      total_members: members,
      total_devotees: devotees.length,
      total_donations: donations.length,
      total_pooja_bookings: pooja,
      total_sankalp_bookings: sankalp,
      total_collection,
      total_outstanding,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/members
router.get('/', verifyToken, requireAdmin, async (req, res) => {
  try {
    const members = await Member.find().sort({ createdAt: -1 }).lean();
    const result = await Promise.all(members.map(async (m) => {
      const devs = await Devotee.find({ member_id: m._id });
      const dons = await Donation.find({ member_id: m._id, paid: true });
      return {
        ...m,
        id: m._id,
        total_collection: devs.reduce((s, d) => s + d.paid_amount, 0) + dons.reduce((s, d) => s + d.amount, 0),
        total_outstanding: devs.reduce((s, d) => s + (d.total_amount - d.paid_amount), 0),
        devotee_count: devs.length,
        donation_count: dons.length,
      };
    }));
    res.json(result);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/members/:id/summary
router.get('/:id/summary', verifyToken, requireAdmin, async (req, res) => {
  try {
    const member = await Member.findById(req.params.id).lean();
    if (!member) return res.status(404).json({ error: 'Member not found' });
    const [devs, dons, pooja, sankalp] = await Promise.all([
      Devotee.find({ member_id: member._id }).lean(),
      Donation.find({ member_id: member._id }).lean(),
      PoojaBooking.find({ member_id: member._id }).lean(),
      SankalpBooking.find({ member_id: member._id }).lean(),
    ]);
    res.json({
      member: { ...member, id: member._id },
      totals: {
        total_collection: devs.reduce((s, d) => s + d.paid_amount, 0) + dons.filter(d => d.paid).reduce((s, d) => s + d.amount, 0),
        total_outstanding: devs.reduce((s, d) => s + (d.total_amount - d.paid_amount), 0),
        devotee_count: devs.length,
        donation_count: dons.length,
      },
      devotees: devs.map(d => ({ ...d, id: d._id })),
      donations: dons.map(d => ({ ...d, id: d._id })),
      pooja_bookings: pooja.map(d => ({ ...d, id: d._id })),
      sankalp_bookings: sankalp.map(d => ({ ...d, id: d._id })),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// PATCH /api/members/:id/status
router.patch('/:id/status', verifyToken, requireAdmin, async (req, res) => {
  try {
    const { status } = req.body;
    if (!['active', 'inactive'].includes(status)) return res.status(400).json({ error: 'status must be active or inactive' });
    const member = await Member.findByIdAndUpdate(req.params.id, { status }, { new: true });
    if (!member) return res.status(404).json({ error: 'Member not found' });
    res.json({ id: member._id, name: member.name, status: member.status });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// PATCH /api/members/:id/reset-password
router.patch('/:id/reset-password', verifyToken, requireAdmin, async (req, res) => {
  try {
    const { password } = req.body;
    if (!password || password.length < 4) return res.status(400).json({ error: 'At least 4 characters required' });
    const password_hash = await bcrypt.hash(password, 10);
    await Member.findByIdAndUpdate(req.params.id, { password_hash });
    res.json({ message: 'Password reset successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
