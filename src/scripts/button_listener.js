const { exec } = require('child_process');
// Para executar comandos e scripts externos
const { Gpio } = require('onoff');
// Biblioteca para controle de GPIO no Raspberry Pi
const path = require('path');
// Para manipulação de caminhos de arquivos

// Caminho absoluto do script que será executado ao pressionar o botão
const SCRIPT_PATH = path.resolve(__dirname, './ativar_modo_ap_reboot.sh');

// Configura o GPIO 17 como entrada, detectando borda de descida (falling edge) com debounce de 10ms
const button = new Gpio(17, 'in', 'falling', { debounceTimeout: 10 });

let emExecucao = false;
// Flag para evitar múltiplas execuções simultâneas do script

// Configura o "watch" para detectar eventos no botão (pressionamento)
button.watch((err, value) => {
  if (err) {
    console.error(`Erro ao ler botão: ${err.message}`);
    return;
  }

  if (emExecucao) {
    console.warn('Script já em execução. Ignorando novo acionamento.');
    return;
  }

  emExecucao = true;
  console.log('Botão pressionado. Executando script.');

  // Executa o script shell configurado
  exec(`bash ${SCRIPT_PATH}`, (error, stdout, stderr) => {
    if (error) {
      console.error(`Erro ao executar script: ${error.message}`);
    }
    if (stderr) {
      console.error(`STDERR: ${stderr}`);
    }
    if (stdout) {
      console.log(`STDOUT: ${stdout}`);
    }
    emExecucao = false;
  });
});

// Tratamento para encerramento do processo via CTRL+C
process.on('SIGINT', () => {
  button.unexport();
  console.log('Encerrando monitoramento do botão.');
  process.exit();
});