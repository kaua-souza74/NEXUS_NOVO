# Arduino físico 001: solicitação, mudanças e diagnóstico

## Solicitação registrada

O usuário pediu para remover o Arduino de teste, investigar por que o dispositivo `001` aparecia desconectado apesar de o Arduino publicar pela COM12, e registrar tanto o que foi pedido quanto o que foi feito.

Depois, pediu que as leituras apareçam em tempo real no Flutter, sem atraso perceptível nem indicação indevida de offline.

## O que foi alterado

- O app representa `ESP32-001` como o dispositivo físico `001` (Arduino UNO R4 WiFi).
- Espaços do banco marcados como teste, incluindo `Sala de Testes`, e o dispositivo legado `ESP32-00` deixam de aparecer no app. Os registros do Supabase não foram apagados nem modificados.
- O consumer MQTT deixou de aceitar mensagens do dispositivo de teste `ESP32-00`; as rotas aceitas para `ESP32-001` continuam sendo `nexus/vista-real/piscina/ESP32-001/readings` e `nexus/vista-real/quarto-101/ESP32-001/readings`.
- A mensagem da bridge em modo contínuo foi ajustada para dizer que a leitura foi enviada ao broker MQTT, sem sugerir que ela já foi persistida.
- A documentação do app explica a regra de status online.
- O Flutter agora assina eventos Realtime autenticados de novas leituras e atualizações do dispositivo físico. Atualiza valores, histórico local da sessão, horário da última leitura e status sem aguardar uma nova consulta completa. A tela sinaliza `AO VIVO` quando a conexão de replicação confirma que está pronta.
- Se o Realtime estiver indisponível, uma consulta de recuperação continua funcionando a cada 15 segundos; quando está ativo, a consulta de segurança ocorre a cada 60 segundos.

## Diagnóstico do status desconectado

O log da bridge confirma que ela leu dados da serial e publicou no broker MQTT. No modo `--once`, a confirmação QoS 1 confirma a entrega ao broker. Nenhum desses logs confirma que o consumer recebeu a mensagem, autenticou o dispositivo e gravou as cinco leituras no Supabase.

O app só marca o dispositivo online quando `last_seen_at` recebido do Supabase está no intervalo dos últimos dois minutos. Portanto, se o consumer não estiver em execução/subscrito, se rejeitar a mensagem, ou se não conseguir persistir no Supabase, o app continuará mostrando o dispositivo desconectado, mesmo com a bridge publicando.

Na etapa de preparação, nem `devices` nem `sensor_readings` estavam na publicação `supabase_realtime`. Após autorização explícita, as duas tabelas foram adicionadas à publicação. A consulta de verificação confirmou ambas. A migration remota `20261030165607_enable_nexus_iot_realtime` também foi registrada no workspace.

Os logs decisivos são os do processo `npm run mqtt:consumer`:

- `Connected` e `Subscribed: nexus/vista-real/+/+/readings` confirmam conexão e inscrição.
- `Device authenticated: ESP32-001` seguido de `5 readings persisted` confirma ingestão e persistência.
- `Message rejected: unauthorized`, `unavailable` ou `invalid_payload` identifica a categoria da rejeição.

Os logs enviados nesta solicitação são somente da bridge. Não permitem determinar qual processo consumer está ativo neste momento nem confirmar a persistência atual. A causa observável fica, portanto, entre ausência de ingestão pelo consumer e falta de atualização de `last_seen_at`; a confirmação final depende do log do consumer e da próxima atualização do app.

## Como verificar no computador do projeto

1. Em um terminal, inicie o consumer: `npm run mqtt:consumer`.
2. Aguarde `Connected` e `Subscribed: nexus/vista-real/+/+/readings`.
3. Em outro terminal, rode a bridge COM12 no modo contínuo já utilizado ou a publicação única já aprovada. Não rode os dois ao mesmo tempo.
4. Confirme no terminal do consumer as linhas `Device authenticated: ESP32-001` e `5 readings persisted`.
5. Atualize o app e aguarde até 30 segundos pela atualização da tela. O status online usa janela de dois minutos após `last_seen_at`.

Se o consumer mostrar rejeição, consulte a configuração local e o acesso de rede sem copiar tokens, hashes ou cabeçalhos para logs ou mensagens. A verificação anterior não confirmou que o token local corresponde à credencial ativa no Supabase; se aparecer `unauthorized`, essa correspondência e a autorização do banco precisam ser verificadas pelo responsável, sem alterar credenciais durante este diagnóstico.

## Limites desta execução

Não foi iniciada nenhuma bridge ou consumer nem houve publicação MQTT, alteração de credenciais, commit ou deploy. A única alteração no Supabase foi adicionar `public.devices` e `public.sensor_readings` à publicação Realtime, conforme autorizado; os dados das tabelas não foram modificados. O estado de execução do consumer não foi observado por esta sessão.

## Verificação de recebimento em 2026-10-30

Às 16:58:09 UTC, a consulta somente leitura ao Supabase encontrou `last_seen_at` do `ESP32-001` em 15:28:31 UTC, idade de 5.378 segundos, e zero leituras nos cinco minutos anteriores. A inspeção local encontrou zero processos `node`, `dart`, `flutter` e `chrome`; portanto, não havia app Flutter visível em execução neste ambiente. O Realtime está habilitado, mas não havia novos eventos para o Flutter receber. Nenhum processo foi iniciado nesta verificação.

Após iniciar os processos no computador do usuário, os logs enviados confirmaram `HMAC authentication PASS`, `Reading authenticated and persisted`, `Device authenticated: ESP32-001` e `5 readings persisted`. A bridge contínua também mostrou leituras sendo enviadas ao broker. Isso confirma a cadeia serial → MQTT → consumer → Supabase; o Flutter aberto pode refletir as leituras pelo Realtime.
