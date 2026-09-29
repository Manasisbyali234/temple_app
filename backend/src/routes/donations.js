const express = require('express');
const { Donation } = require('../models');
const { verifyToken, requireMember } = require('../middleware/auth');

const router = express.Router();

router.post('/', verifyToken, requireMember, async (req, res) => {
  try {
    const { donor_name, donor_phone, section, description, amount, payment_method, paid, donation_date } = req.body;
    if (!donor_name || !section) return res.status(400).json({ error: 'donor_name and section are required' });
    const doc = await Donation.create({ member_id: req.user.id, donor_name, donor_phone, section, description, amount: Number(amount) || 0, payment_method: payment_method || 'cash', paid: paid !== false, donation_date: donation_date || new Date() });
    res.status(201).json({ ...doc.toObject(), id: doc._id });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/', verifyToken, requireMember, async (req, res) => {
  try {
    const filter = { member_id: req.user.id };
    if (req.query.section) filter.section = req.query.section;
    if (req.query.paid !== undefined) filter.paid = req.query.paid === 'true';
    const rows = await Donation.find(filter).sort({ donation_date: -1 }).lean();
    res.json(rows.map(d => ({ ...d, id: d._id })));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/summary/me', verifyToken, requireMember, async (req, res) => {
  try {
    const dons = await Donation.find({ member_id: req.user.id, paid: true }).lean();
    const bySection = {};
    for (const d of dons) bySection[d.section] = (bySection[d.section] || 0) + d.amount;
    res.json(Object.entries(bySection).map(([section, total_paid]) => ({ section, total_paid })));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
