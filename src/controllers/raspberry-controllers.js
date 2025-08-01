const fs = require('fs');
const { execFile } = require('child_process');

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
      // iwgetid -r retorna o nome da rede Wi-Fi atual (SSID)
      redeAtual = execSync('iwgetid -r').toString().trim();
    } catch (e) {
      // Não está conectado a nenhuma rede, ou iwgetid não retornou nada
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

    const scriptPath = path.resolve(__dirname, '../scripts/configurar_wifi.sh');

    res.status(200).json({
      retorno: { status: 200, mensagem: `Iniciando conexão com a rede ${ssid}...` }
    });

    const child = spawn('sudo', [scriptPath, ssid, password], {
      detached: true,
      stdio: 'ignore'
    });

    child.unref();

    console.log(`Script de conexão Wi-Fi iniciado para SSID: ${ssid}`);

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

