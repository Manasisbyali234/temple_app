const express = require('express');
const { Banner } = require('../models');
const { verifyToken, requireMember } = require('../middleware/auth');

const router = express.Router();

router.post('/', verifyToken, requireMember, async (req, res) => {
  try {
    const { title, image_url, description, start_date, end_date, start_time, end_time } = req.body;
    if (!title || !start_date || !end_date) return res.status(400).json({ error: 'title, start_date and end_date are required' });
    const doc = await Banner.create({ member_id: req.user.id, title, image_url, description, start_date, end_date, start_time, end_time });
    res.status(201).json({ ...doc.toObject(), id: doc._id });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/', verifyToken, async (req, res) => {
  try {
    const rows = await Banner.find({ member_id: req.user.id }).sort({ createdAt: -1 }).lean();
    res.json(rows.map(d => ({ ...d, id: d._id })));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
