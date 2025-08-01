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

exports.conectWifiRaspberry = async (req, res, next) => {
    try {
        const { ssid, password } = req.body;
        console.log(`SSID: ${ssid} - Password: ${password}`);

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

            console.log('stdout:', stdout);
            console.log('stderr:', stderr);

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