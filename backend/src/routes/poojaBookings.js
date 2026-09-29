const express = require('express');
const { PoojaBooking } = require('../models');
const { verifyToken, requireMember } = require('../middleware/auth');

const router = express.Router();

router.post('/', verifyToken, requireMember, async (req, res) => {
  try {
    const { devotee_name, phone, pooja_name, booking_date, booking_time, amount, payment_method } = req.body;
    if (!devotee_name || !pooja_name || !booking_date) return res.status(400).json({ error: 'devotee_name, pooja_name and booking_date are required' });
    const doc = await PoojaBooking.create({ member_id: req.user.id, devotee_name, phone, pooja_name, booking_date, booking_time, amount: Number(amount) || 0, payment_method: payment_method || 'cash' });
    res.status(201).json({ ...doc.toObject(), id: doc._id });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/', verifyToken, requireMember, async (req, res) => {
  try {
    const rows = await PoojaBooking.find({ member_id: req.user.id }).sort({ booking_date: -1 }).lean();
    res.json(rows.map(d => ({ ...d, id: d._id })));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
