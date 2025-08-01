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

const path = '/home/pi/Desktop/api/src/scripts/configurar_wifi.sh';

const { spawn } = require('child_process');
const path = require('path');

exports.conectWifiRaspberry = (req, res) => {
  try {
    const { ssid, password } = req.body;

    if (!ssid || !password) {
      return res.status(400).json({
        retorno: { status: 400, mensagem: 'ssid e password são obrigatórios' }
      });
    }

    const scriptPath = path.resolve(__dirname, '../scripts/configurar_wifi.sh');

    // Responde imediatamente pro cliente
    res.status(200).json({
      retorno: { status: 200, mensagem: `Iniciando conexão com a rede ${ssid}...` }
    });

    // Executa o script em background (independente da conexão HTTP)
    const child = spawn('sudo', [scriptPath, ssid, password], {
      detached: true,
      stdio: 'ignore'
    });

    child.unref(); // Desacopla o processo filho

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

