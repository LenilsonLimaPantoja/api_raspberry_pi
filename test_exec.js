const { execFile } = require('child_process');

const path = '/home/pi/Desktop/api/src/scripts/configurar_wifi.sh';
const ssid = 'GE-CLARO';
const password = 'Gem5a970**';

execFile('sudo', [path, ssid, password], (error, stdout, stderr) => {
    if (error) {
        console.error('Erro ao executar o script:', error.message);
        console.error('stderr:', stderr);
        return;
    }

    console.log('stdout:', stdout);
    console.log('stderr:', stderr);
});
