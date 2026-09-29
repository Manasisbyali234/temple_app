const express = require('express');
const { Meeting } = require('../models');
const { verifyToken, requireMember } = require('../middleware/auth');

const router = express.Router();

router.post('/', verifyToken, requireMember, async (req, res) => {
  try {
    const { title, meeting_date, meeting_time, notes, items } = req.body;
    if (!title || !meeting_date) return res.status(400).json({ error: 'title and meeting_date are required' });
    const doc = await Meeting.create({ member_id: req.user.id, title, meeting_date, meeting_time, notes, items: Array.isArray(items) ? items : [] });
    res.status(201).json({ ...doc.toObject(), id: doc._id });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/', verifyToken, requireMember, async (req, res) => {
  try {
    const rows = await Meeting.find({ member_id: req.user.id }).sort({ meeting_date: -1 }).lean();
    res.json(rows.map(d => ({ ...d, id: d._id })));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
