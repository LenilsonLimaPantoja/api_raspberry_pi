const fs = require('fs');
const { exec } = require('child_process');

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
                retorno: {
                    status: 400,
                    mensagem: 'ssid e password são obrigatórios'
                },
                registros: []
            });
        }
        const wpaConf = `ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
                            update_config=1
                            country=BR

                            network={
                                ssid="${ssid}"
                                psk="${password}"
                                key_mgmt=WPA-PSK
                            }
                        `;

        fs.writeFile('/etc/wpa_supplicant/wpa_supplicant.conf', wpaConf, (err) => {
            if (err) {
                console.error('Erro ao salvar wpa_supplicant.conf:', err);
                return res.status(500).json({
                    retorno: {
                        status: 500,
                        mensagem: 'Falha ao configurar Wi-Fi', err
                    },
                    registros: []
                });
            }

            exec('sudo wpa_cli -i wlan0 reconfigure', (error, stdout, stderr) => {
                if (error) {
                    console.error('Erro ao reiniciar wpa_supplicant:', error);
                    return res.status(500).json({
                        retorno: {
                            status: 500,
                            mensagem: 'Falha ao reiniciar serviço Wi-Fi'
                        },
                        registros: []
                    });
                }
                res.status(200).json({
                    retorno: {
                        status: 500,
                        mensagem: `Conectando à rede Wi-Fi ${ssid}`
                    },
                    registros: []
                });
            });
        });
    } catch (error) {
        console.error("Erro ao conectar a rede:", error);
        res.status(500).send({
            retorno: {
                status: 500,
                mensagem: "Erro ao conectar a rede, tente novamente.",
                erro: error.message
            },
            registros: []
        });
    }
};