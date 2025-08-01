const express = require('express');
const routes = express.Router();

const raspberryController = require("../controllers/raspberry-controllers.js");

routes.get('/serial', raspberryController.readSerialRaspberry);
routes.post('/connect-wifi', raspberryController.conectWifiRaspberry);

module.exports = routes;