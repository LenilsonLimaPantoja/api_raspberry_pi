const express = require('express');
const bodyParser = require('body-parser');
const morgan = require('morgan');
const app = express();

// Importando as rotas
const raspberryController = require('./src/routes/raspberry.routes');

// Usando o morgan para logs
app.use(morgan('dev'));

// Usando o body-parser para lidar com o corpo das requisições
app.use(bodyParser.urlencoded({ extended: false }));
app.use(bodyParser.json());

// Configuração do CORS (caso necessário) - ajustada para permitir credenciais
app.use((req, res, next) => {
    // Verifica se a origem da requisição está na lista de origens permitidas
    res.header("Access-Control-Allow-Origin", "*"); // Permite todos os frontends
    res.header("Access-Control-Allow-Credentials", "true"); // Permite cookies e credenciais
    res.header(
        "Access-Control-Allow-Headers",
        "Origin, X-Requested-With, Content-Type, Accept, Authorization"
    );

    if (req.method === "OPTIONS") {
        res.header("Access-Control-Allow-Methods", "PUT, POST, PATCH, DELETE, GET");
        return res.status(200).send({});
    }

    next();
});

// Defina suas rotas e configure o servidor Express
app.use('/raspberry', raspberryController);

// Middleware para tratamento de URL não encontrada
app.use((req, res, next) => {
    const error = new Error("Url não encontrada, tente novamente");
    error.status = 404;
    next(error);
});

// Middleware para tratamento de erros gerais
app.use((error, req, res, next) => {
    res.status(error.status || 500);
    return res.send({
        error: {
            message: error.message,
        },
    });
});

module.exports = app;