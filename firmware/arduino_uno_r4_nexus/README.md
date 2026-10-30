# Firmware Arduino UNO R4 WiFi — NEXUS

## Ligações

- DHT11: dados em D2.
- Fotoresistor: saída analógica em A0.
- Botão de presença: entre D4 e GND; a entrada usa `INPUT_PULLUP`.
- Porta: reportada como fechada (`door_open: false`) nesta etapa.

## Preparação e gravação

1. No Arduino IDE, instale a placa **Arduino UNO R4 Boards** e selecione **Arduino UNO R4 WiFi**.
2. No Library Manager, instale **DHT sensor library** da Adafruit e a dependência **Adafruit Unified Sensor**.
3. Abra `arduino_uno_r4_nexus.ino`, selecione a porta da placa e carregue o firmware.
4. O Serial Monitor e o Plotter Serial podem ser usados para conferir a saída em 115200 baud. Feche-os antes de abrir a bridge, pois a porta COM só pode ser aberta por um programa de cada vez.

O firmware não escreve mensagens de inicialização ou diagnóstico na serial. Cada amostra válida é uma linha JSON UTF-8 a 115200 baud, aproximadamente a cada 2,5 segundos. Valores inválidos do DHT11 são descartados. A luminosidade é a leitura ADC bruta de 10 bits (0–1023). Um clique estável no botão alterna presença.

## Bridge local

No diretório raiz do projeto, configure `NEXUS_DEVICE_TOKEN_ESP32_001` em `.env.local` com o token local já provisionado para o dispositivo `ESP32-001`. Não coloque esse arquivo no Git. O token bruto fica somente no computador; a bridge calcula internamente o hash e assina o envelope com o helper compartilhado pelo consumer.

Para validar o cabo/serial e o formato sem publicar MQTT:

```powershell
npm run arduino:bridge:dry-run -- --port COM11
```

O Monitor Serial deve estar fechado. O dry-run continua lendo a serial, valida as linhas e prepara a assinatura, mas não se conecta ao broker nem publica mensagens. A primeira execução em modo MQTT deve aguardar autorização explícita do responsável pelo projeto.

Para a primeira publicação controlada, a bridge aceita `--once`: abre a porta,
aguarda a primeira linha JSON válida, assina o envelope, publica uma vez com
QoS 1 e encerra após o callback MQTT. Se a publicação falhar, não tenta de
novo. A linha do consumer aceita o tópico legado `quarto-101` como alias para
`ESP32-001`, mantendo também o tópico atual da Piscina; o banco associa a
leitura ao espaço cadastrado para o dispositivo.

Depois da autorização explícita, execute na raiz do repositório:

```powershell
npm run arduino:bridge -- --port COM12 --once
```
