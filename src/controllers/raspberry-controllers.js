const fs = require('fs');

exports.readSerialRaspberry = async (req, res, next) => {
  try {
    const cpuInfo = fs.readFileSync('/proc/cpuinfo', 'utf8');
    const serialLine = cpuInfo.split('\n').find(line => line.startsWith('Serial'));
    if (serialLine) {
      return res.status(200).send({
        retorno: {
          status: 200,
          mensagem: 'Número de série encontrado com sucesso!'
        },
        registros: [
          {
            serial: serialLine.split(':')[1].trim()
          }
        ]
      });
    } else {
      return res.status(404).send({
        retorno: {
          status: 404,
          mensagem: 'Número de série não encontrado.'
        },
        registros: []
      });
    }
  } catch (error) {
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

const { spawn, execSync } = require('child_process');
const path = require('path');

exports.conectWifiRaspberry = (req, res) => {
  try {
    const { ssid, password } = req.body;

    if (!ssid || !password) {
      return res.status(400).json({
        retorno: { status: 400, mensagem: 'ssid e password são obrigatórios' }
      });
    }

    // Verifica se já está conectado a uma rede
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
          mensagem: `O Raspberry já está conectado à rede '${redeAtual}'. Para conectar a uma nova rede, é necessário resetar o dispositivo.`
        }
      });
    }

    const scriptConfigPath = path.resolve(__dirname, '../scripts/configurar_wifi.sh');
    const scriptWatchdogPath = path.resolve(__dirname, '../scripts/watchdog_wifi.sh');

    // Resposta imediata ao cliente
    res.status(200).json({
      retorno: { status: 200, mensagem: `Iniciando conexão com a rede ${ssid}...` }
    });

    // Executa o script de configuração Wi-Fi
    const childConfig = spawn('sudo', [scriptConfigPath, ssid, password]);

    childConfig.on('close', (code) => {
      console.log(`configurar_wifi.sh finalizado com código ${code}`);

      // Após tentar configurar a rede, executa o watchdog para monitorar e ativar AP se necessário
      const childWatchdog = spawn('sudo', [scriptWatchdogPath], {
        detached: true,
        stdio: 'ignore'
      });
      childWatchdog.unref();
      console.log('Watchdog Wi-Fi iniciado para monitorar a conexão.');
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

