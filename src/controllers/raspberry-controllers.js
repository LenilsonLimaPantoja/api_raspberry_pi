const fs = require('fs'); 
// Módulo para manipular arquivos

const { spawn, execSync } = require('child_process'); 
// spawn para executar processos de forma assíncrona; execSync para comandos síncronos

const path = require('path'); 
// Para trabalhar com caminhos de arquivos

// Função para ler o número de série do Raspberry Pi e responder ao cliente
exports.readSerialRaspberry = async (req, res, next) => {
  try {
    // Lê o arquivo /proc/cpuinfo que contém informações da CPU
    const cpuInfo = fs.readFileSync('/proc/cpuinfo', 'utf8');
    // Procura a linha que começa com 'Serial'
    const serialLine = cpuInfo.split('\n').find(line => line.startsWith('Serial'));

    if (serialLine) {
      // Se encontrou, responde com status 200 e número de série
      return res.status(200).send({
        retorno: {
          status: 200,
          mensagem: 'Número de série encontrado com sucesso!'
        },
        registros: [
          {
            serial: serialLine.split(':')[1].trim() // Extrai o número após ":"
          }
        ]
      });
    } else {
      // Se não encontrou, responde com status 404
      return res.status(404).send({
        retorno: {
          status: 404,
          mensagem: 'Número de série não encontrado.'
        },
        registros: []
      });
    }
  } catch (error) {
    // Em caso de erro ao ler o arquivo, retorna status 500 com mensagem e erro
    console.error("Erro ao buscar número de série:", error);
    res.status(500).send({
      retorno: {
        status: 500,
        mensagem: "Erro ao buscar número de série, tente novamente.",
        erro: error.message
      },
      registros: []
    });
  }
};

exports.conectWifiRaspberry = (req, res) => {
  try {
    const { ssid, password } = req.body;

    const cpuInfo = fs.readFileSync('/proc/cpuinfo', 'utf8');
    const serialLine = cpuInfo.split('\n').find(line => line.startsWith('Serial'));
    const serial = serialLine ? serialLine.split(':')[1].trim() : '000000';

    if (!ssid || !password) {
      return res.status(400).json({
        retorno: { status: 400, mensagem: 'ssid e password são obrigatórios' }
      });
    }

    let redeAtual = '';
    try {
      redeAtual = execSync('iwgetid -r').toString().trim();
    } catch {
      redeAtual = '';
    }

    if (redeAtual) {
      return res.status(200).json({
        retorno: {
          status: 200,
          mensagem: `Já conectado à rede '${redeAtual}'. Reinicie para trocar.`
        }
      });
    }

    const scriptConfigPath = path.resolve(__dirname, '../scripts/configurar_wifi.sh');
    const scriptWatchdogPath = path.resolve(__dirname, '../scripts/watchdog_wifi.sh');

    // Gera hostname para exibir no frontend
    const ssidLimpo = ssid.replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
    const serialFinal = serial.slice(-6);
    const hostname = `${ssidLimpo}-${serialFinal}`;

    // Resposta imediata
    res.status(200).json({
      retorno: { status: 200, mensagem: `Iniciando conexão com a rede ${ssid}... Verifique os indicadores luminosos na placa para confirmar o status da conexão.` },
      registros: [
        { serial },
        { hostname: `${hostname}.local`, url: `http://${hostname}.local` }
      ]
    });

    // Executa script de configuração
    const childConfig = spawn('sudo', [scriptConfigPath, ssid, password, serial]);

    childConfig.stdout.on('data', (data) => {
      console.log(`[configurar_wifi.sh stdout]: ${data}`);
    });

    childConfig.stderr.on('data', (data) => {
      console.error(`[configurar_wifi.sh stderr]: ${data}`);
    });

    childConfig.on('close', (code) => {
      console.log(`configurar_wifi.sh finalizado com código ${code}`);

      // Inicia watchdog
      const childWatchdog = spawn('sudo', [scriptWatchdogPath], {
        detached: true,
        stdio: 'ignore'
      });
      childWatchdog.unref();
      console.log('Watchdog iniciado.');
    });

  } catch (error) {
    console.error("Erro na função conectWifiRaspberry:", error);
    return res.status(500).json({
      retorno: {
        status: 500,
        mensagem: "Erro ao conectar à rede, tente novamente.",
        erro: error.message
      }
    });
  }
};
