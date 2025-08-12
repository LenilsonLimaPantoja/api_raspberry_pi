const express = require('express'); 
// Importa o framework Express para criar rotas e gerenciar requisições HTTP

const routes = express.Router(); 
// Cria um objeto Router para definir rotas agrupadas

const raspberryController = require("../controllers/raspberry-controllers.js"); 
// Importa o controlador com as funções que serão chamadas nas rotas

// Define uma rota GET no caminho '/serial' que chama a função readSerialRaspberry do controlador
routes.get('/serial', raspberryController.readSerialRaspberry);

// Define uma rota POST no caminho '/connect-wifi' que chama a função conectWifiRaspberry do controlador
routes.post('/connect-wifi', raspberryController.conectWifiRaspberry);

// Exporta as rotas para serem usadas em outro arquivo, normalmente no app principal
module.exports = routes;
