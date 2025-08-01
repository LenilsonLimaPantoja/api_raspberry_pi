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
        console.log(`Conectando à rede Wi-Fi - SSID: ${ssid}, PASSWORD: ${'*'.repeat(password.length)}`);

        if (!ssid || !password) {
            return res.status(400).send({
                retorno: {
                    status: 400,
                    mensagem: 'ssid e password são obrigatórios'
                },
                registros: []
            });
        }

        const child = execFile('sudo', [path, ssid, password], { timeout: 10000 }, (error, stdout, stderr) => {
            if (error) {
                console.error('Erro ao executar o script:', error);
                return res.status(500).send({
                    retorno: {
                        status: 500,
                        mensagem: 'Falha ao configurar Wi-Fi.',
                        erro: error.message
                    },
                    registros: []
                });
            }

            const output = stdout.trim() || stderr.trim() || `Conectado à rede ${ssid}.`;
            console.log('Saída do script:', output);

            return res.status(200).send({
                retorno: {
                    status: 200,
                    mensagem: output
                },
                registros: []
            });
        });

        // Precaução: se o cliente desconectar, mata o processo do script
        req.on('close', () => {
            if (child && !child.killed) {
                child.kill();
                console.log('Requisição cancelada. Processo filho encerrado.');
            }
        });

    } catch (error) {
        console.error("Erro ao tentar executar o script de conexão Wi-Fi:", error);
        return res.status(500).send({
            retorno: {
                status: 500,
                mensagem: 'Erro ao conectar à rede.',
                erro: error.message
            },
            registros: []
        });
    }
};
