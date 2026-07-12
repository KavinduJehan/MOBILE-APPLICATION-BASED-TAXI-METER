require('dotenv').config();
const app = require('./app');
const connectDB = require('./config/db');
const configRoutes = require('./routes/config');

connectDB();

app.use('/api/config', configRoutes);

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
