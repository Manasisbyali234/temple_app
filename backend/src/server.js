require('dotenv').config();
require('./db'); // connect to MongoDB
const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const memberRoutes = require('./routes/members');
const devoteeRoutes = require('./routes/devotees');
const donationRoutes = require('./routes/donations');
const bannerRoutes = require('./routes/banners');
const poojaBookingRoutes = require('./routes/poojaBookings');
const sankalpBookingRoutes = require('./routes/sankalpBookings');
const meetingRoutes = require('./routes/meetings');

const app = express();
app.use(cors());
app.use(express.json());

app.get('/', (req, res) => res.json({ status: 'ok', service: 'temple-collection-backend' }));

app.use('/api/auth', authRoutes);
app.use('/api/members', memberRoutes);
app.use('/api/devotees', devoteeRoutes);
app.use('/api/donations', donationRoutes);
app.use('/api/banners', bannerRoutes);
app.use('/api/pooja-bookings', poojaBookingRoutes);
app.use('/api/sankalp-bookings', sankalpBookingRoutes);
app.use('/api/meetings', meetingRoutes);

// 404 handler
app.use((req, res) => res.status(404).json({ error: 'Not found' }));

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
