const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Admin, Member } = require('../models');
const { verifyToken, requireAdmin } = require('../middleware/auth');

const router = express.Router();

function signToken(payload) {
  return jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });
}

// POST /api/auth/admin/login
router.post('/admin/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'Email and password are required' });
    const admin = await Admin.findOne({ email: email.toLowerCase() });
    if (!admin) return res.status(401).json({ error: 'Invalid credentials' });
    const match = await bcrypt.compare(password, admin.password_hash);
    if (!match) return res.status(401).json({ error: 'Invalid credentials' });
    const token = signToken({ id: admin._id, role: 'admin', name: admin.name, email: admin.email });
    res.json({ token, user: { id: admin._id, name: admin.name, email: admin.email, role: 'admin' } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/auth/member/login
router.post('/member/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'Email and password are required' });
    const member = await Member.findOne({ email: email.toLowerCase() });
    if (!member) return res.status(401).json({ error: 'No member account found for that email.' });
    if (member.status !== 'active') return res.status(403).json({ error: 'Account is inactive. Contact admin.' });
    const match = await bcrypt.compare(password, member.password_hash);
    if (!match) return res.status(401).json({ error: 'Wrong password.' });
    const token = signToken({ id: member._id, role: 'member', name: member.name, email: member.email });
    res.json({ token, user: { id: member._id, name: member.name, email: member.email, phone: member.phone, role: 'member' } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/auth/members  (Admin creates a member)
router.post('/members', verifyToken, requireAdmin, async (req, res) => {
  try {
    const { name, email, phone, password } = req.body;
    if (!name || !email || !phone || !password) {
      return res.status(400).json({ error: 'name, email, phone and password are required' });
    }
    const existing = await Member.findOne({ email: email.toLowerCase() });
    if (existing) return res.status(409).json({ error: 'A member with this email already exists' });
    const password_hash = await bcrypt.hash(password, 10);
    const member = await Member.create({ name, email, phone, password_hash, created_by: req.user.id });
    res.status(201).json({ id: member._id, name: member.name, email: member.email, phone: member.phone, status: member.status });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
