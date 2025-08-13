const express = require('express');  // Importa o framework Express para criar o servidor
const bodyParser = require('body-parser');  // Middleware para interpretar corpo das requisições
const morgan = require('morgan');  // Middleware para logs HTTP
const app = express();  // Cria a instância do Express

// Importando as rotas do módulo raspberry.routes.js
const raspberryRoutes = require('./src/routes/raspberry.routes');

// Usa o morgan para mostrar logs de requisições no console (modo 'dev')
app.use(morgan('dev'));

// Configura o body-parser para interpretar dados enviados via POST (URL encoded e JSON)
app.use(bodyParser.urlencoded({ extended: false }));
app.use(bodyParser.json());

// Configuração do CORS para permitir que frontends acessem a API
app.use((req, res, next) => {
    // Permite acesso de qualquer origem
    res.header("Access-Control-Allow-Origin", "*");

    // Permite que cookies e credenciais sejam enviados (se necessário)
    res.header("Access-Control-Allow-Credentials", "true");

    // Permite esses headers nas requisições
    res.header(
        "Access-Control-Allow-Headers",
        "Origin, X-Requested-With, Content-Type, Accept, Authorization"
    );

    // Se for uma requisição do tipo OPTIONS (prévia do CORS)
    if (req.method === "OPTIONS") {
        // Permite os métodos HTTP listados
        res.header("Access-Control-Allow-Methods", "PUT, POST, PATCH, DELETE, GET");
        // Envia resposta OK para a requisição OPTIONS
        return res.status(200).send({});
    }

    // Passa para o próximo middleware/rota
    next();
});

// Define as rotas a partir do caminho '/raspberry', usando o controlador importado
app.use('/raspberry', raspberryRoutes);

// Middleware para tratar URLs que não foram encontradas nas rotas anteriores
app.use((req, res, next) => {
    const error = new Error("Url não encontrada, tente novamente"); // Cria erro
    error.status = 404; // Define status HTTP 404
    next(error); // Passa o erro para o middleware de erro
});

// Middleware para tratamento geral de erros da aplicação
app.use((error, req, res, next) => {
    res.status(error.status || 500); // Usa status do erro ou 500 (erro interno)
    return res.send({
        error: {
            message: error.message, // Envia mensagem do erro para o cliente
        },
    });
});

module.exports = app;  // Exporta a instância do Express para ser usada em outro arquivo (ex: servidor)
