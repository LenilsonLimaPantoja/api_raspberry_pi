// Importa a instância do Express que está configurada no arquivo app.js
const app = require('./app.js');

// Define a porta para o servidor ouvir, usando variável de ambiente PORT ou 5002 como padrão
const PORT = process.env.PORT || 5002;

// Inicia o servidor HTTP e fica ouvindo na porta definida
app.listen(PORT, () => {
  // Quando o servidor iniciar com sucesso, imprime essa mensagem no console
  console.log(`Servidor Express está ouvindo na porta ${PORT}`);
});
