const HX711 = require('@shroudedcode/hx711');
const axios = require('axios');
const fs = require('fs');

const DT_PIN = 5;
const SCK_PIN = 6;

const sensor = new HX711({
  dataPin: DT_PIN,
  clockPin: SCK_PIN,
  gain: 128
});

const getSerial = () => {
  try {
    const cpuInfo = fs.readFileSync('/proc/cpuinfo', 'utf8');
    const serialLine = cpuInfo.split('\n').find(line => line.startsWith('Serial'));
    return serialLine ? serialLine.split(':')[1].trim() : '000000';
  } catch (err) {
    console.error('Erro ao ler serial do Raspberry:', err.message);
    return '000000';
  }
};

const SERIAL_RPI = getSerial();
let pesoAnterior = null;

exports.iniciarLeituraBalanca = () => {
  sensor.tare()
    .then(() => {
      console.log('Balança pronta.');
      setInterval(async () => {
        try {
          const peso = Math.max(0, parseInt(await sensor.getUnits(5)));

          if (peso !== pesoAnterior) {
            pesoAnterior = peso;
            console.log(`Peso lido: ${peso} g`);

            try {
              await axios.post('http://api-pesagem.vercel.app/peso-caixa', {
                peso_atual: peso,
                identificador_balanca: SERIAL_RPI
              });
              console.log('Peso enviado com sucesso para api-pesagem.vercel.app');
            } catch (err) {
              console.error('Erro ao enviar peso:', err.message);
            }
          }
        } catch (err) {
          console.error('Erro ao ler o peso:', err.message);
        }
      }, 2000);
    })
    .catch(err => console.error('Erro ao tarear a balança:', err));
};