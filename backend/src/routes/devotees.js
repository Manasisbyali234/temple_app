const express = require('express');
const { Devotee } = require('../models');
const { verifyToken, requireMember } = require('../middleware/auth');

const router = express.Router();

router.post('/', verifyToken, requireMember, async (req, res) => {
  try {
    const { name, address, phone, initial_payment, payment_method, total_amount } = req.body;
    if (!name) return res.status(400).json({ error: 'name is required' });
    const paid = Number(initial_payment) || 0;
    const total = total_amount != null ? Number(total_amount) : paid;
    const status = paid <= 0 ? 'pending' : paid >= total ? 'paid' : 'partially_paid';
    const dev = await Devotee.create({ member_id: req.user.id, name, address, phone, initial_payment: paid, payment_method: payment_method || 'cash', total_amount: total, paid_amount: paid, status });
    res.status(201).json({ ...dev.toObject(), id: dev._id });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/', verifyToken, requireMember, async (req, res) => {
  try {
    const filter = { member_id: req.user.id };
    if (req.query.status) filter.status = req.query.status;
    const rows = await Devotee.find(filter).sort({ createdAt: -1 }).lean();
    res.json(rows.map(d => ({ ...d, id: d._id })));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/summary/me', verifyToken, requireMember, async (req, res) => {
  try {
    const devs = await Devotee.find({ member_id: req.user.id });
    res.json({
      total_collected: devs.reduce((s, d) => s + d.paid_amount, 0),
      total_outstanding: devs.reduce((s, d) => s + (d.total_amount - d.paid_amount), 0),
      count: devs.length,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.patch('/:id/pay', verifyToken, requireMember, async (req, res) => {
  try {
    const amt = Number(req.body.amount);
    if (!amt || amt <= 0) return res.status(400).json({ error: 'A positive amount is required' });
    const dev = await Devotee.findOne({ _id: req.params.id, member_id: req.user.id });
    if (!dev) return res.status(404).json({ error: 'Devotee not found' });
    dev.paid_amount += amt;
    if (req.body.payment_method) dev.payment_method = req.body.payment_method;
    dev.status = dev.paid_amount >= dev.total_amount ? 'paid' : 'partially_paid';
    await dev.save();
    res.json({ ...dev.toObject(), id: dev._id });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
