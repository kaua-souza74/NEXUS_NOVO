# NEXUS · ESP32-00 físico

Sketch Arduino para a montagem física descrita no projeto. Ele lê DHT11, LDR e
um botão que simula presença, assina o envelope MQTT com HMAC-SHA256 e publica
a cada 10 s.

## Ligações

| Módulo | Sinal | GPIO |
| --- | --- | ---: |
| DHT11 | S | 4 |
| LDR | S analógico | 34 |
| Botão de 3 pinos (presença) | S | 27 |

Alimente os módulos em 3V3 e GND do ESP32. GPIO34 é somente entrada e é
apropriado para o sinal analógico do LDR. O botão de presença usa
`INPUT_PULLDOWN`: pressionado deve levar o sinal do GPIO27 a 3V3, gerando
`presence = true`. Não conecte botão algum ao GPIO26.

Se o DHT11 for o sensor avulso de quatro pinos (sem placa adaptadora), instale
um resistor de pull-up de 4,7 kΩ a 10 kΩ entre DATA e 3V3. Não use 5V nos sinais
do ESP32.

## Arduino IDE 1.8.19

1. Em **Arquivo > Preferências**, adicione esta URL em **URLs adicionais para
   Gerenciadores de Placas**: `https://espressif.github.io/arduino-esp32/package_esp32_index.json`.
2. Em **Ferramentas > Placa > Gerenciador de Placas**, instale **esp32 by
   Espressif Systems** e reinicie a IDE.
3. Selecione **ESP32 Dev Module** em **Ferramentas > Placa > esp32**. A imagem
   enviada estava selecionada como **Arduino Uno**; troque essa seleção.
4. Em **Ferramentas > Porta**, escolha a COM que aparecer ao conectar o ESP32.
   Ela não estava disponível durante a preparação deste sketch.
5. Em **Sketch > Incluir Biblioteca > Gerenciar Bibliotecas**, instale:
   - **ArduinoMqttClient** (Arduino)
   - **DHT sensor library** (Adafruit)
   - **Adafruit Unified Sensor** (dependência do DHT)
6. Copie `arduino_secrets.example.h` para `arduino_secrets.h` na mesma pasta do
   sketch e preencha SSID e senha do Wi-Fi 2,4 GHz. Depois que o ESP32-00 for
   provisionado, coloque o token exclusivo dele nesse arquivo local. O token
   da simulação `ESP32-001` não serve para este dispositivo. O backend guarda
   somente o hash do token; nunca versione `arduino_secrets.h` nem compartilhe
   o token em capturas de tela.
7. Abra `esp32_nexus.ino`, clique em **Verificar** e depois **Carregar**. Se a
   gravação parar em `Connecting...`, pressione e segure **BOOT** até iniciar.
8. Abra **Ferramentas > Monitor Serial**, velocidade **115200**.

## Protocolo NEXUS

- Broker: `broker.emqx.io:1883` (TCP sem TLS, para demo).
- Tópico: `nexus/vista-real/quarto-101/ESP32-00/readings`.
- O relógio é sincronizado por NTP antes de publicar; o backend aceita timestamp
  dentro de ±60 s e nonce único.
- A canonical message segue a ordem do backend:
  `[device_id,timestamp,nonce,temperature,humidity,presence,light,door_open]`.
- O firmware calcula SHA-256 do token UTF-8 e usa os 32 bytes resultantes como
  chave HMAC-SHA256. A assinatura é hex lowercase.
- Temperatura e umidade são arredondadas para inteiros, luz é leitura ADC raw
  (0–4095), e presença é `true` enquanto o botão no GPIO27 estiver pressionado.
- O contrato atual do backend exige `door_open`; como não há sensor de porta,
  o firmware sempre envia `door_open: false`.
- Cada mensagem autenticada gera cinco leituras no banco e atualiza
  `last_seen_at` pelo consumer.

## Teste real

Inicie o consumer no repositório com `npm run mqtt:consumer`. No MQTT.Cool,
conecte a `broker.emqx.io:1883` e assine o tópico acima. Depois de carregar o
firmware, confirme no Monitor Serial que houve conexão Wi-Fi/MQTT e publicação;
confirme no consumer `Device authenticated: ESP32-00` e `5 readings persisted`.
Não publique payload de teste manual com credencial real no tópico: a mensagem
do próprio ESP32 é o teste real e evita gravar leituras falsas.

O broker público é compartilhado e não cifra a conexão na porta 1883. Use-o
somente para desenvolvimento/demo; para produção, migre para broker privado com
TLS e ACL por dispositivo.
