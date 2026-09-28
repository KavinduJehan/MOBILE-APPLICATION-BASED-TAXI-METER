require('dotenv').config();
const http = require('http');
const { Server } = require('socket.io');
const app = require('./app');
const connectDB = require('./config/db');
const configRoutes = require('./routes/config');

connectDB();

app.use('/api/config', configRoutes);

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE'],
  },
});

app.set('io', io);

io.on('connection', (socket) => {
  // Client joins their personal room by user/driver ID or trip room
  socket.on('join', (userId) => {
    if (userId) {
      socket.join(userId.toString());
    }
  });

  socket.on('join_trip', (tripId) => {
    if (tripId) {
      socket.join(tripId.toString());
    }
  });

  // Low-latency direct socket driver location broadcast
  socket.on('driver_location_update', (data) => {
    if (!data) return;
    const { customerId, tripId, lat, lng, driverId } = data;
    const payload = { driverId, tripId, lat, lng };
    if (customerId) {
      io.to(customerId.toString()).emit('driver_location', payload);
    }
    if (tripId) {
      io.to(tripId.toString()).emit('driver_location', payload);
    }
  });

  socket.on('disconnect', () => {});
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => console.log(`Server running on port ${PORT}`));
