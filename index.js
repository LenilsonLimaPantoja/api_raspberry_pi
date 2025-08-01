const express = require('express');
const fs = require('fs');
const { exec } = require('child_process');

const app = express();
const PORT = 3000;

// Middleware para interpretar JSON no corpo da requisição
app.use(express.json());

// Função para ler número de série
function getSerialNumber() {
    try {
        const cpuInfo = fs.readFileSync('/proc/cpuinfo', 'utf8');
        const serialLine = cpuInfo.split('\n').find(line => line.startsWith('Serial'));
        if (serialLine) {
            return serialLine.split(':')[1].trim();
        } else {
            return 'Serial não encontrado';
        }
    } catch (err) {
        return 'Erro ao ler o número de série';
    }
}

app.get('/serial', (req, res) => {
    const serial = getSerialNumber();
    res.json({ serial });
});

// Rota para conectar Wi-Fi
app.post('/connect-wifi', (req, res) => {
    const { ssid, password } = req.body;

    if (!ssid || !password) {
        return res.status(400).json({ error: 'ssid e password são obrigatórios' });
    }

    const wpaConf = `
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
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
            return res.status(500).json({ error: 'Falha ao configurar Wi-Fi', err });
        }

        exec('sudo wpa_cli -i wlan0 reconfigure', (error, stdout, stderr) => {
            if (error) {
                console.error('Erro ao reiniciar wpa_supplicant:', error);
                return res.status(500).json({ error: 'Falha ao reiniciar serviço Wi-Fi' });
            }
            res.json({ message: `Conectando à rede Wi-Fi ${ssid}` });
        });
    });
});

app.listen(PORT, () => {
    console.log(`Servidor rodando em http://localhost:${PORT}`);
});