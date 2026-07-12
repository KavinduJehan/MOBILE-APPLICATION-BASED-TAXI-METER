const express = require('express');
const router = express.Router();
const { getPublicConfig } = require('../controllers/systemConfigController');

router.get('/public', getPublicConfig);

module.exports = router;
