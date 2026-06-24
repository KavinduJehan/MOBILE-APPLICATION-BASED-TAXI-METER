require('dotenv').config();
const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const driverRoutes = require('./routes/drivers');
const tripRoutes = require('./routes/trips');
const rateRoutes = require('./routes/rates');
const adminRoutes = require('./routes/admin');
const rideRequestRoutes = require('./routes/rideRequests');
const customerRoutes = require('./routes/customers');

const app = express();

app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/drivers', driverRoutes);
app.use('/api/trips', tripRoutes);
app.use('/api/rates', rateRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/ride-requests', rideRequestRoutes);
app.use('/api/customers', customerRoutes);

app.get('/health', (req, res) => res.json({ status: 'ok' }));

module.exports = app;
