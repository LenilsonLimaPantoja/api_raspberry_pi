const fs = require('fs');
const { execFile } = require('child_process');
const path = '/home/pi/api_raspberry_pi/src/scripts/configurar_wifi.sh';

exports.readSerialRaspberry = async (req, res, next) => {
    try {

        const cpuInfo = fs.readFileSync('/proc/cpuinfo', 'utf8');
        const serialLine = cpuInfo.split('\n').find(line => line.startsWith('Serial'));
        if (serialLine) {
            return res.status(200).send({
                retorno: {
                    status: 200,
                    mensagem: 'Número de serie encontrado com sucesso!'
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
                    mensagem: 'Número de serie encontrado com sucesso!'
                },
                registros: [
                    {
                        serial: serialLine.split(':')[1].trim()
                    }
                ]
            });
        }

    } catch (error) {
        console.error("Erro ao buscar número de serie:", error);
        res.status(500).send({
            retorno: {
                status: 500,
                mensagem: "Erro ao buscar número de serie, tente novamente.",
                erro: error.message
            },
            registros: []
        });
    }
};

exports.conectWifiRaspberry = async (req, res, next) => {
  try {
    const { ssid, password } = req.body;
    if (!ssid || !password) {
      return res.status(400).json({
        retorno: { status: 400, mensagem: 'ssid e password são obrigatórios' },
        registros: []
      });
    }

    execFile('sudo', [path, ssid, password], (error, stdout, stderr) => {
      if (error) {
        console.error('Erro ao executar script configurar_wifi.sh:', error);
        return res.status(500).json({
          retorno: { status: 500, mensagem: 'Falha ao configurar Wi-Fi', erro: error.message },
          registros: []
        });
      }

      res.status(200).json({
        retorno: { status: 200, mensagem: `Conectando à rede Wi-Fi ${ssid}` },
        registros: []
      });
    });
  } catch (error) {
    console.error("Erro ao conectar a rede:", error);
    res.status(500).json({
      retorno: { status: 500, mensagem: "Erro ao conectar a rede, tente novamente.", erro: error.message },
      registros: []
    });
  }
};