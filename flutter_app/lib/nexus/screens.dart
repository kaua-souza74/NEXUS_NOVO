import 'package:flutter/material.dart';
import 'design.dart';
import 'store.dart';
import 'app.dart' show Brand;

const gap = SizedBox(height: 16);
Widget bodyColumn(List<Widget> children) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
Widget detailBody(List<Widget> children) =>
    Scaffold(body: SafeArea(child: PageScroll(children: children)));
String _sensorName(dynamic value) => switch (value?.toString()) {
      'temperature' => 'Temperatura',
      'humidity' => 'Umidade',
      'presence' => 'Presença',
      'light' => 'Luminosidade',
      'door' => 'Porta',
      _ => 'Leitura',
    };

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onTab});
  final ValueChanged<int> onTab;
  @override
  Widget build(BuildContext context) {
    final s = NexusScope.of(context);
    return PageScroll(
        key: const PageStorageKey('home'),
        horizontalPadding: 12,
        children: [
          Row(children: [
            const Brand(),
            const Spacer(),
            IconButton(
                tooltip: 'Demonstração',
                onPressed: () => showSimulation(context),
                icon: const Icon(Icons.tune_rounded)),
            IconButton(
                tooltip: 'Ver alertas',
                onPressed: () => onTab(3),
                icon: Badge(
                    label: Text('${s.activeAlerts}'),
                    isLabelVisible: s.activeAlerts > 0,
                    child: const Icon(Icons.notifications_outlined)))
          ]),
          const SizedBox(height: 24),
          DataGate(
              child: bodyColumn([
            Enter(
                child: Surface(
                    dark: true,
                    backgroundImage: 'assets/images/lobby-evening.png',
                    padding: const EdgeInsets.all(26),
                    child: bodyColumn([
                      Row(children: [
                        Pill(
                            s.state == ViewState.offline
                                ? 'ÚLTIMA LEITURA'
                                : s.paused
                                    ? 'PAUSADO'
                                    : s.databaseSyncedAt != null
                                        ? 'SUPABASE + DEMO'
                                        : 'DEMONSTRAÇÃO',
                            dark: true,
                            dot: s.databaseSyncedAt != null),
                        const Spacer(),
                        Text(timeLabel(s.updatedAt),
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12))
                      ]),
                      const SizedBox(height: 25),
                      Text(s.hotelName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -.7)),
                      const SizedBox(height: 18),
                      AnimatedNumber(s.databaseSpaceCount.toDouble(),
                          style: const TextStyle(
                              fontSize: 82,
                              height: 1.05,
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -5)),
                      const Text('espaços cadastrados no banco',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 22),
                      Pill(
                          s.activeAlerts == 0
                              ? 'Sem alertas de demonstração'
                              : '${s.activeAlerts} alerta(s) de demonstração',
                          dark: true,
                          icon: s.activeAlerts == 0
                              ? Icons.check_circle_outline
                              : Icons.error_outline),
                      const SizedBox(height: 25),
                      GlassPanel(
                          padding: const EdgeInsets.symmetric(
                              vertical: 15, horizontal: 14),
                          child: Row(children: [
                            Expanded(
                                child: _HeroStat(
                                    '${s.databaseOnlineDeviceCount}', 'Banco online', N.peach)),
                            Expanded(
                                child: _HeroStat(
                                    '${s.databaseDeviceCount - s.databaseOnlineDeviceCount}',
                                    'Banco offline',
                                    Colors.white60)),
                            Expanded(
                                child: _HeroStat('${s.simulatedDeviceCount}', 'Simulados',
                                    const Color(0xFFF4B7A8)))
                          ])),
                    ]))),
            const Section('Dados reais · Supabase'),
            Surface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    const Icon(Icons.verified_user_outlined,
                        color: N.wine, size: 20),
                    const SizedBox(width: 9),
                    Expanded(
                        child: Text(
                            s.databaseSyncedAt == null
                                ? 'Aguardando leitura protegida por RLS'
                                : 'Sessão autenticada sincronizada',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13))),
                    IconButton(
                        tooltip: 'Atualizar Supabase',
                        onPressed: () { s.refreshFromDatabase(); },
                        icon: const Icon(Icons.refresh_rounded, size: 20))
                  ]),
                  Text(
                      '${s.hotelName} · ${s.databaseSpaceCount} espaço · ${s.databaseDeviceCount} dispositivo · ${s.databaseReadings.length} leituras',
                      style: const TextStyle(color: N.muted, fontSize: 11)),
                  if (s.databaseError != null) ...[
                    const SizedBox(height: 8),
                    const Text('Não foi possível atualizar os dados do banco. Verifique a sessão e as policies RLS.',
                        style: TextStyle(color: N.red, fontSize: 11)),
                  ],
                  if (s.databaseReadings.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    for (final row in s.databaseReadings.take(5))
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                              '${_sensorName(row['sensor_type'])}: ${row['value_boolean'] ?? row['value_numeric'] ?? '—'}${row['unit'] == null ? '' : ' ${row['unit']}'}',
                              style: const TextStyle(
                                  color: N.ink, fontSize: 11))),
                  ],
                  if (s.databaseSyncedAt != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text('Atualizado ${timeLabel(s.databaseSyncedAt!)} · leituras não são simuladas nesta seção',
                            style: const TextStyle(
                                color: N.muted, fontSize: 10))),
                ])),
            const Section('Acesso rápido'),
            Row(children: [
              _Quick('Espaços', Icons.grid_view_rounded, () => onTab(1)),
              _Quick('Dispositivos', Icons.sensors_rounded, () => onTab(2)),
              _Quick('Alertas', Icons.notifications_outlined, () => onTab(3))
            ]),
            Section('Espaços ao vivo',
                action: 'Ver todos', onAction: () => onTab(1)),
            SizedBox(
                height: 229,
                child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    separatorBuilder: (_, i) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final space =
                          s.space(['room101', 'lobby', 'restaurant', 'gym'][i]);
                      return SizedBox(
                          width: 250,
                          child: SpaceCard(space,
                              alert: s.alertsIn(space.id).isNotEmpty,
                              onTap: () =>
                                  openPage(context, SpaceDetail(space.id))));
                    })),
            Section('Atividade do hotel',
                action: 'Analytics ↗',
                onAction: () => openPage(context, const AnalyticsPage())),
            Enter(
                index: 2,
                child: Surface(
                    dark: true,
                    onTap: () => openPage(context, const AnalyticsPage()),
                    child: bodyColumn([
                      const Row(children: [
                        Expanded(
                            child: Text('Ocupação agora',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12))),
                        Pill('Hoje', dark: true)
                      ]),
                      AnimatedNumber(s.activity,
                          suffix: '%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 43,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -2)),
                      const SizedBox(height: 4),
                      Text('${s.occupiedSpaces} espaços com presença detectada',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11)),
                      const SizedBox(height: 22),
                      NexusChart(
                          values:
                              s.activityHistory.map((v) => v * 100).toList(),
                          dark: true,
                          unit: '%')
                    ]))),
            const Section('Equilíbrio dos ambientes'),
            Surface(
                child: Column(children: [
              Row(children: [
                Expanded(
                    child: EnvironmentRing(
                        label: 'Temperatura',
                        value: s.averageTemperature,
                        maximum: 40,
                        unit: '°C',
                        decimals: 1,
                        color: N.wine)),
                Expanded(
                    child: EnvironmentRing(
                        label: 'Umidade',
                        value: s.averageHumidity,
                        maximum: 100,
                        unit: '%',
                        color: N.rose)),
                Expanded(
                    child: EnvironmentRing(
                        label: 'Luminosidade',
                        value: s.averageLight,
                        maximum: 1200,
                        unit: 'lx',
                        color: N.amber)),
              ]),
              const SizedBox(height: 18),
              Text(
                  '${s.occupiedSpaces} espaços ocupados · médias dos sensores online',
                  style: const TextStyle(color: N.muted, fontSize: 11))
            ])),
            const SizedBox(height: 22),
            Text('DADOS DE DEMONSTRAÇÃO · ${s.databaseSpaceCount} ESPAÇO(S) E ${s.databaseDeviceCount} DISPOSITIVO(S) DO SUPABASE',
                style:
                    TextStyle(color: N.muted, fontSize: 9, letterSpacing: 1.2)),
          ])),
        ]);
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat(this.value, this.label, this.color);
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => bodyColumn([
        Text(value,
            style: TextStyle(
                color: color, fontSize: 25, fontWeight: FontWeight.w500)),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11))
      ]);
}

class _Quick extends StatelessWidget {
  const _Quick(this.label, this.icon, this.action);
  final String label;
  final IconData icon;
  final VoidCallback action;
  @override
  Widget build(BuildContext context) => Expanded(
      child: TapScale(
          onTap: action,
          child: Column(children: [
            Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: Icon(icon, color: N.wine, size: 24)),
            const SizedBox(height: 9),
            Text(label, style: const TextStyle(fontSize: 11, color: N.muted))
          ])));
}

class SpacesPage extends StatefulWidget {
  const SpacesPage({super.key});
  @override
  State<SpacesPage> createState() => _SpacesPageState();
}

class _SpacesPageState extends State<SpacesPage> {
  String filter = 'Todos';
  @override
  Widget build(BuildContext context) {
    final s = NexusScope.of(context);
    final items = s.spaces
        .where((v) => switch (filter) {
              'Ocupados' => v.online && v.presence,
              'Livres' => v.online && !v.presence,
              'Em alerta' => s.alertsIn(v.id).isNotEmpty,
              'Offline' => !v.online,
              _ => true
            })
        .toList();
    return PageScroll(children: [
      Heading('Espaços',
          subtitle: '${s.databaseSpaceCount} no Supabase · demais ambientes demonstrativos.'),
      const PhotoBanner(
          image: 'assets/images/hotel-corridor.png',
          eyebrow: 'Ambientes conectados',
          title: 'Cada espaço, em perspectiva.',
          subtitle: 'Condições atuais e presença em um só lugar.'),
      gap,
      FilterPills(
          items: const ['Todos', 'Ocupados', 'Livres', 'Em alerta', 'Offline'],
          selected: filter,
          onChanged: (v) => setState(() => filter = v)),
      const SizedBox(height: 22),
      DataGate(
          child: items.isEmpty
              ? const EmptyPanel(
                  icon: Icons.check_circle_outline,
                  title: 'Tudo tranquilo por aqui',
                  message: 'Nenhum espaço corresponde a este filtro.')
              : ResponsiveGrid(minWidth: 270, children: [
                  for (var i = 0; i < items.length; i++)
                    Enter(
                        index: i,
                        child: SpaceCard(items[i],
                            alert: s.alertsIn(items[i].id).isNotEmpty,
                            onTap: () =>
                                openPage(context, SpaceDetail(items[i].id))))
                ]))
    ]);
  }
}

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});
  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  String filter = 'Todos';
  @override
  Widget build(BuildContext context) {
    final s = NexusScope.of(context);
    final items = s.devices
        .where((d) => switch (filter) {
              'Online' => d.online,
              'Offline' => !d.online,
              'Atenção' => s.alertsIn(d.spaceId).isNotEmpty,
              _ => true
            })
        .toList();
    items.sort((a, b) => a.id.compareTo(b.id));
    return PageScroll(children: [
      PhotoBanner(
          image: 'assets/images/hotel-corridor.png',
          eyebrow: '${s.simulatedDeviceCount} simulados · ${s.databaseDeviceCount} do Supabase · ESP32-00 físico',
          title: 'Dispositivos',
          subtitle: 'Conexões e leituras dos seus ambientes.',
          trailing:
              const Icon(Icons.sensors_rounded, color: Colors.white, size: 25),
          footer: GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(children: [
                Expanded(
                    child:
                        _DeviceStat('${s.databaseOnlineDeviceCount}', 'Banco online', N.peach)),
                Container(
                    width: 1,
                    height: 34,
                    color: Colors.white.withValues(alpha: .22)),
                Expanded(
                    child: _DeviceStat('${s.databaseDeviceCount - s.databaseOnlineDeviceCount}',
                        'Banco offline', Colors.white))
              ]))),
      gap,
      FilterPills(
          items: const ['Todos', 'Online', 'Offline', 'Atenção'],
          selected: filter,
          onChanged: (v) => setState(() => filter = v)),
      const SizedBox(height: 22),
      DataGate(
          child: items.isEmpty
              ? const EmptyPanel(
                  icon: Icons.sensors_off,
                  title: 'Nenhum dispositivo',
                  message: 'Experimente outro filtro.')
              : ResponsiveGrid(
                  minWidth: 280,
                  children: items.map((d) => DeviceCard(d)).toList()))
    ]);
  }
}

class DeviceCard extends StatelessWidget {
  const DeviceCard(this.device, {super.key});
  final DeviceData device;
  @override
  Widget build(BuildContext context) {
    final s = NexusScope.of(context);
    return Surface(
        onTap: () => openPage(
            context,
            device.physical
                ? const Esp32PhysicalTestPage()
                : DeviceDetail(device.id)),
        child: bodyColumn([
          Row(children: [
            Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                    color: N.canvas, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.memory_rounded, color: N.wine)),
            const SizedBox(width: 12),
            Expanded(
                child: bodyColumn([
              Text('${device.id} · ${device.name == device.id ? (device.physical ? 'Arduino físico' : 'Dispositivo') : device.name}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              Text(s.space(device.spaceId).name,
                  style: const TextStyle(color: N.muted, fontSize: 12))
            ])),
            const Icon(Icons.chevron_right, color: N.muted)
          ]),
          gap,
          Row(children: [
            Pill(
                device.physical
                    ? 'Testes pendentes'
                    : device.online
                        ? 'Online'
                        : 'Offline',
                dot: !device.physical && device.online,
                color: device.physical
                    ? N.amber
                    : device.online
                        ? N.green
                        : N.muted),
            const Spacer(),
            Text(device.physical
                    ? 'hardware físico'
                    : device.databaseBacked
                        ? 'Wokwi · Supabase'
                        : 'simulado',
                style: const TextStyle(color: N.muted, fontSize: 11))
          ]),
          const SizedBox(height: 14),
          Text(device.physical
                  ? 'Página de testes · sem gravação no banco'
                  : 'DHT22 · LDR · PIR · Reed switch · ${device.databaseBacked ? 'leituras salvas no Supabase' : 'simulação local'}',
              style: const TextStyle(color: N.muted, fontSize: 10))
        ]));
  }
}

class _DeviceStat extends StatelessWidget {
  const _DeviceStat(this.value, this.label, this.color);
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 23,
                height: 1,
                fontWeight: FontWeight.w600,
                letterSpacing: -.6)),
        const SizedBox(height: 5),
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500))
      ]);
}

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});
  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  String status = 'Ativos', level = 'Todos';
  @override
  Widget build(BuildContext context) {
    final s = NexusScope.of(context);
    final items = s.alerts
        .where((a) =>
            a.resolved == (status == 'Resolvidos') &&
            (level == 'Todos' || alertLevelLabel(a.level) == level))
        .toList();
    return PageScroll(children: [
      PhotoBanner(
          image: 'assets/images/night-reception.png',
          eyebrow: 'Monitoramento contínuo',
          title: 'Alertas',
          subtitle: '${s.activeAlerts} ativos · acompanhe o que importa.',
          trailing: Icon(
              s.activeAlerts > 0
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_none,
              color: Colors.white,
              size: 24)),
      gap,
      Row(children: [
        Expanded(
            child: Surface(
                padding: const EdgeInsets.all(15),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: N.red, size: 19),
                      const SizedBox(height: 11),
                      Text('${s.activeAlerts}',
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w600)),
                      const Text('Ativos agora',
                          style: TextStyle(fontSize: 10, color: N.muted))
                    ]))),
        const SizedBox(width: 11),
        Expanded(
            child: Surface(
                padding: const EdgeInsets.all(15),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          color: N.green, size: 19),
                      const SizedBox(height: 11),
                      Text('${s.alerts.length - s.activeAlerts}',
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w600)),
                      const Text('Resolvidos',
                          style: TextStyle(fontSize: 10, color: N.muted))
                    ])))
      ]),
      gap,
      FilterPills(
          items: const ['Ativos', 'Resolvidos'],
          selected: status,
          onChanged: (v) => setState(() => status = v)),
      gap,
      FilterPills(
          items: const ['Todos', 'Crítico', 'Atenção', 'Informativo'],
          selected: level,
          onChanged: (v) => setState(() => level = v)),
      const SizedBox(height: 22),
      DataGate(
          child: items.isEmpty
              ? const EmptyPanel(
                  icon: Icons.check_circle_outline,
                  title: 'Nenhum alerta por aqui',
                  message: 'Os ambientes estão dentro das condições esperadas.')
              : bodyColumn([
                  for (final a in items)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Surface(
                            onTap: () => openPage(context, AlertDetail(a.id)),
                            child: bodyColumn([
                              Row(children: [
                                Pill(
                                    a.resolved
                                        ? 'Resolvido'
                                        : alertLevelLabel(a.level),
                                    color: a.resolved
                                        ? N.green
                                        : alertColor(a.level)),
                                const Spacer(),
                                Text(ageLabel(a.detected),
                                    style: const TextStyle(
                                        fontSize: 10, color: N.muted))
                              ]),
                              gap,
                              Text(a.title,
                                  style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -.4)),
                              const SizedBox(height: 6),
                              Text('${s.space(a.spaceId).name} · ${a.deviceId}',
                                  style: const TextStyle(
                                      color: N.muted, fontSize: 12)),
                              const SizedBox(height: 12),
                              Text(a.description,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: N.muted,
                                      height: 1.5)),
                              const SizedBox(height: 12),
                              const Row(children: [
                                Text('Ver ocorrência',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: N.wine)),
                                Spacer(),
                                Icon(Icons.arrow_outward,
                                    size: 17, color: N.wine)
                              ])
                            ])))
                ]))
    ]);
  }
}

class SpaceDetail extends StatefulWidget {
  const SpaceDetail(this.id, {super.key});
  final String id;
  @override
  State<SpaceDetail> createState() => _SpaceDetailState();
}

class _SpaceDetailState extends State<SpaceDetail> {
  String period = '1H';
  @override
  Widget build(BuildContext context) {
    final s = NexusScope.of(context);
    final v = s.space(widget.id);
    return detailBody([
      const Heading('Seu ambiente', back: true),
      DataGate(
          child: bodyColumn([
        Surface(
            dark: true,
            child: bodyColumn([
              SpaceHero(v, dark: true),
              const SizedBox(height: 22),
              Row(children: [
                Pill(v.online ? 'Monitoramento ativo' : 'Sem comunicação',
                    dark: true, dot: v.online),
                const Spacer(),
                Icon(spaceIcon(v.id), size: 42, color: Colors.white24)
              ]),
              const SizedBox(height: 22),
              AnimatedNumber(v.temperature,
                  decimals: 1,
                  suffix: '°C',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 61, letterSpacing: -3)),
              Text(
                  v.online
                      ? 'Última leitura ${timeLabel(v.lastReading)}'
                      : 'Última leitura preservada · ${ageLabel(v.lastReading)}',
                  style: const TextStyle(fontSize: 12, color: Colors.white60))
            ])),
        const Section('Sensores do ambiente'),
        ResponsiveGrid(children: [
          Metric(
              label: 'Umidade',
              value: v.humidity,
              unit: '%',
              icon: Icons.water_drop_outlined),
          Metric(
              label: 'Luminosidade',
              value: v.light.toDouble(),
              unit: ' lx',
              icon: Icons.light_mode_outlined)
        ]),
        gap,
        ResponsiveGrid(children: [
          _StatusSensor('Presença', v.presence ? 'Detectada' : 'Sem presença',
              Icons.person_outline, v.presence),
          _StatusSensor('Porta', v.doorOpen ? 'Aberta' : 'Fechada',
              Icons.sensor_door_outlined, v.doorOpen)
        ]),
        const Section('Temperatura ao longo do tempo'),
        FilterPills(
            items: const ['1H', '6H', '24H', '7D'],
            selected: period,
            onChanged: (p) => setState(() => period = p)),
        gap,
        Surface(
            child: NexusChart(
                key: ValueKey(period),
                values: s.series('Temperatura', period, spaceId: v.id),
                unit: '°C',
                labels: periodLabels(period))),
        const Section('Dispositivos conectados'),
        for (final d in s.devicesIn(v.id))
          Padding(
              padding: const EdgeInsets.only(bottom: 12), child: DeviceCard(d)),
        const Section('Eventos recentes'),
        Surface(
            child: bodyColumn([
          for (final e in v.events)
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                    backgroundColor: N.canvas,
                    child: Icon(eventIcon(e.kind), color: N.wine, size: 18)),
                title: Text(e.message, style: const TextStyle(fontSize: 12)),
                subtitle: Text(ageLabel(e.time),
                    style: const TextStyle(fontSize: 10, color: N.muted)))
        ]))
      ]))
    ]);
  }
}

class _StatusSensor extends StatelessWidget {
  const _StatusSensor(this.label, this.value, this.icon, this.active);
  final String label, value;
  final IconData icon;
  final bool active;
  @override
  Widget build(BuildContext context) => Surface(
      color: active ? const Color(0xFFECE1DE) : Colors.white,
      child: bodyColumn([
        Icon(icon, color: N.wine),
        const SizedBox(height: 20),
        Text(value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: N.muted))
      ]));
}

List<String> periodLabels(String period) => switch (period) {
      '1H' => ['−60 min', '−40 min', '−20 min', 'Agora'],
      '6H' => ['−6 h', '−4 h', '−2 h', 'Agora'],
      '7D' => ['−7d', '−4d', '−2d', 'Hoje'],
      _ => ['−24h', '−16h', '−8h', 'Agora']
    };

class Esp32PhysicalTestPage extends StatefulWidget {
  const Esp32PhysicalTestPage({super.key});

  @override
  State<Esp32PhysicalTestPage> createState() => _Esp32PhysicalTestPageState();
}

class _Esp32PhysicalTestPageState extends State<Esp32PhysicalTestPage> {
  static const _checks = <(String, String, IconData)>[
    ('wifi', 'Wi-Fi 2,4 GHz', Icons.wifi_rounded),
    ('mqtt', 'MQTT · broker e tópico', Icons.hub_outlined),
    ('dht11', 'DHT11 · temperatura e umidade', Icons.thermostat_outlined),
    ('ldr', 'LDR · luminosidade', Icons.light_mode_outlined),
    ('button', 'Botão · presença simulada (GPIO 27)', Icons.touch_app_outlined),
    ('hmac', 'Autenticação HMAC-SHA256', Icons.verified_user_outlined),
    ('supabase', 'Consumer · Supabase', Icons.storage_rounded),
  ];
  final _passed = <String>{};
  bool _validated = false;

  @override
  Widget build(BuildContext context) => detailBody([
        const Heading('ESP32-00', back: true, subtitle: 'Arduino físico · testes de bancada'),
        Surface(
            dark: true,
            child: bodyColumn([
              Row(children: [
                const Icon(Icons.memory_rounded, color: N.peach, size: 42),
                const Spacer(),
                const Pill('FÍSICO · NÃO INTEGRADO', dark: true)
              ]),
              const SizedBox(height: 20),
              const Text('Preparação do dispositivo',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              const Text(
                  'O ESP32-00 é a placa física. Use este checklist de bancada para conferir sensores, conexão MQTT e ingestão.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
            ])),
        const Section('Checklist de testes'),
        Surface(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(children: [
              for (final (id, label, icon) in _checks)
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(icon, color: N.wine, size: 20),
                    title: Text(label, style: const TextStyle(fontSize: 13)),
                    value: _passed.contains(id),
                    activeColor: N.wine,
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _passed.add(id);
                      } else {
                        _passed.remove(id);
                      }
                      _validated = false;
                    })),
            ])),
        gap,
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(
              onPressed: () => setState(() => _validated = true),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Validar checklist')),
          OutlinedButton.icon(
              onPressed: () => setState(() {
                _passed.clear();
                _validated = false;
              }),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Limpar')),
        ]),
        if (_validated) ...[
          gap,
          Surface(
              color: _passed.length == _checks.length
                  ? const Color(0xFFE5EFE9)
                  : const Color(0xFFF3E8DB),
              child: Row(children: [
                Icon(
                    _passed.length == _checks.length
                        ? Icons.check_circle_outline
                        : Icons.pending_actions_outlined,
                    color: _passed.length == _checks.length ? N.green : N.amber),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                        '${_passed.length}/${_checks.length} itens marcados · ${_passed.length == _checks.length ? 'bancada pronta para integração' : 'há testes pendentes'}',
                        style: const TextStyle(fontSize: 12))),
              ])),
        ],
        const Section('Contrato previsto'),
        const Surface(
            child: Column(children: [
          KeyValue('Identificador', 'ESP32-00'),
          KeyValue('Transporte', 'MQTT · broker.emqx.io:1883'),
          KeyValue('Tópico', 'nexus/vista-real/quarto-101/ESP32-00/readings'),
          KeyValue('Sensores', 'DHT11 · LDR · botão de presença'),
          KeyValue('Pinos', 'GPIO 4 · 27 · 34'),
          KeyValue('Persistência', 'Após provisionar device e credencial'),
        ])),
        gap,
        const Text(
            'O checklist é local e temporário. O firmware publicado só será autenticado e persistido depois que o ESP32-00 e sua credencial exclusiva estiverem provisionados.',
            style: TextStyle(fontSize: 11, color: N.muted, height: 1.45)),
      ]);
}

class DeviceDetail extends StatelessWidget {
  const DeviceDetail(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context) {
    final s = NexusScope.of(context);
    final d = s.device(id), v = s.space(d.spaceId);
    return detailBody([
      Heading(id, back: true, subtitle: v.name),
      DataGate(
          child: bodyColumn([
        Surface(
            dark: true,
            child: bodyColumn([
              Row(children: [
                const Icon(Icons.memory_rounded, color: N.peach, size: 42),
                const Spacer(),
                Pill(d.online ? 'Online' : 'Offline', dark: true, dot: d.online)
              ]),
              const SizedBox(height: 24),
              Text(d.online ? 'Conectado ao ambiente' : 'Conexão interrompida',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 7),
              Text('Última comunicação ${ageLabel(d.lastSeen)}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12))
            ])),
        const Section('Leituras dos sensores'),
        ResponsiveGrid(children: [
          Metric(
              label: 'DHT22 · Temperatura',
              value: v.temperature,
              decimals: 1,
              unit: '°C',
              icon: Icons.thermostat_outlined),
          Metric(
              label: 'DHT22 · Umidade',
              value: v.humidity,
              unit: '%',
              icon: Icons.water_drop_outlined),
          Metric(
              label: 'LDR · Luminosidade',
              value: v.light.toDouble(),
              unit: ' lx',
              icon: Icons.light_mode_outlined),
          _StatusSensor('PIR · Presença', v.presence ? 'Detectada' : 'Ausente',
              Icons.person_outline, v.presence)
        ]),
        gap,
        _StatusSensor('Reed switch · Porta', v.doorOpen ? 'Aberta' : 'Fechada',
            Icons.sensor_door_outlined, v.doorOpen),
        const Section('Histórico de temperatura'),
        Surface(child: NexusChart(values: v.history, unit: '°C')),
        const Section('Informações técnicas'),
        Surface(
            child: bodyColumn([
          KeyValue('Modelo', d.databaseBacked ? 'ESP32 · origem Wokwi' : 'ESP32 DevKit V1 · demo'),
          KeyValue('Firmware', d.databaseBacked ? 'Não informado pelo banco' : 'NEXUS 1.0.0-demo'),
          KeyValue('Protocolo', d.databaseBacked ? 'Ingestão registrada no Supabase' : 'Simulação local'),
          KeyValue('Tópico', d.databaseBacked ? 'nexus/vista-real/quarto-101/ESP32-001/readings' : '—'),
          KeyValue('Intervalo', d.databaseBacked ? 'Definido pelo dispositivo' : '6 segundos · demo'),
          KeyValue('Mensagens recebidas', '${d.messages}'),
          KeyValue('Sinal Wi-Fi', d.databaseBacked ? 'Não armazenado' : d.online ? '−58 dBm · demo' : 'Indisponível'),
          KeyValue('Saúde', d.online ? 'Operacional' : 'Verificar conexão')
        ])),
        gap,
        OutlinedButton.icon(
            onPressed: () => openPage(context, SpaceDetail(v.id)),
            icon: const Icon(Icons.grid_view_rounded),
            label: const Text('Ver espaço'))
      ]))
    ]);
  }
}

class AlertDetail extends StatelessWidget {
  const AlertDetail(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context) {
    final s = NexusScope.of(context);
    final a = s.alerts.firstWhere((a) => a.id == id);
    final v = s.space(a.spaceId);
    return detailBody([
      const Heading('Ocorrência', back: true),
      DataGate(
          child: bodyColumn([
        Surface(
            dark: true,
            child: bodyColumn([
              Row(children: [
                Pill(a.resolved ? 'Resolvido' : alertLevelLabel(a.level),
                    dark: true),
                const Spacer(),
                const Icon(Icons.notifications_active_outlined,
                    color: N.peach, size: 28)
              ]),
              const SizedBox(height: 26),
              Text(a.title,
                  style: const TextStyle(
                      fontSize: 29,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -1)),
              const SizedBox(height: 14),
              Text(a.description,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.6))
            ])),
        const Section('Contexto do alerta'),
        Surface(
            child: bodyColumn([
          KeyValue('Espaço', v.name),
          KeyValue('Dispositivo', a.deviceId),
          KeyValue('Detectado',
              '${a.detected.day}/${a.detected.month} · ${timeLabel(a.detected)}'),
          KeyValue('Status', a.resolved ? 'Resolvido localmente' : 'Ativo'),
          KeyValue(
              'Temperatura atual', '${v.temperature.toStringAsFixed(1)} °C')
        ])),
        const Section('Leituras próximas à ocorrência'),
        Surface(child: NexusChart(values: v.history, unit: '°C')),
        const SizedBox(height: 24),
        SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
                onPressed: a.resolved ? null : () => s.resolve(a.id),
                icon: Icon(a.resolved ? Icons.check : Icons.task_alt),
                label: Text(a.resolved
                    ? 'Alerta resolvido'
                    : 'Marcar como resolvido'))),
        gap,
        Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: () => openPage(context, SpaceDetail(v.id)),
                  child: const Text('Ver espaço'))),
          const SizedBox(width: 12),
          Expanded(
              child: OutlinedButton(
                  onPressed: () => openPage(context, DeviceDetail(a.deviceId)),
                  child: const Text('Ver dispositivo')))
        ]),
        gap,
        const Text('As ações desta demonstração são mantidas durante a sessão.',
            style: TextStyle(color: N.muted, fontSize: 11))
      ]))
    ]);
  }
}

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String period = 'Hoje', metric = 'Ocupação';
  @override
  Widget build(BuildContext context) {
    final s = NexusScope.of(context);
    final vals = s.series(metric, period);
    return detailBody([
      const Heading('Analytics',
          back: true, subtitle: 'Transforme leituras em uma visão do hotel.'),
      FilterPills(
          items: const ['Hoje', '7 dias', '30 dias'],
          selected: period,
          onChanged: (v) => setState(() => period = v)),
      const SizedBox(height: 22),
      DataGate(
          child: bodyColumn([
        Surface(
            dark: true,
            child: bodyColumn([
              const Text('Atividade dos ambientes',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 14),
              AnimatedNumber(s.periodAverage('Ocupação', period),
                  suffix: '%',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 64, letterSpacing: -3)),
              const Text('ocupação média estimada no período',
                  style: TextStyle(color: Colors.white60, fontSize: 11)),
              const SizedBox(height: 24),
              NexusChart(
                  values: s.series('Ocupação', period),
                  dark: true,
                  unit: '%',
                  labels: period == 'Hoje'
                      ? const ['−24h', '−16h', '−8h', 'Agora']
                      : period == '7 dias'
                          ? const ['−7d', '−4d', '−2d', 'Hoje']
                          : const ['−30d', '−20d', '−10d', 'Hoje'])
            ])),
        const Section('Condições e operação'),
        ResponsiveGrid(children: [
          Metric(
              label: 'Temperatura média',
              value: s.periodAverage('Temperatura', period),
              decimals: 1,
              unit: '°C',
              icon: Icons.thermostat_outlined),
          Metric(
              label: 'Umidade média',
              value: s.periodAverage('Umidade', period),
              unit: '%',
              icon: Icons.water_drop_outlined),
          Metric(
              label: 'Dispositivos online',
              value: s.onlineDevices / s.devices.length * 100,
              unit: '%',
              icon: Icons.sensors),
          Metric(
              label: 'Alertas no período',
              value: (period == 'Hoje'
                      ? s.alerts.length
                      : period == '7 dias'
                          ? 34
                          : 126)
                  .toDouble(),
              icon: Icons.notifications_outlined)
        ]),
        const Section('Explore as leituras'),
        FilterPills(
            items: const ['Ocupação', 'Temperatura', 'Umidade'],
            selected: metric,
            onChanged: (v) => setState(() => metric = v)),
        gap,
        Surface(
            child: NexusChart(
                key: ValueKey('$period-$metric'),
                values: vals,
                labels: period == 'Hoje'
                    ? const ['−24h', '−16h', '−8h', 'Agora']
                    : period == '7 dias'
                        ? const ['−7d', '−4d', '−2d', 'Hoje']
                        : const ['−30d', '−20d', '−10d', 'Hoje'],
                unit: metric == 'Temperatura' ? '°C' : '%')),
        const Section('Espaços mais ativos'),
        Surface(
            child: bodyColumn([
          for (final id in ['lobby', 'restaurant', 'pool', 'conference'])
            ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => openPage(context, SpaceDetail(id)),
                leading: CircleAvatar(
                    backgroundColor: N.canvas,
                    child: Icon(spaceIcon(id), color: N.wine, size: 20)),
                title: Text(s.space(id).name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: LinearProgressIndicator(
                    value: id == 'lobby'
                        ? 0.92
                        : id == 'restaurant'
                            ? 0.81
                            : 0.74,
                    color: N.rose,
                    backgroundColor: N.canvas,
                    borderRadius: BorderRadius.circular(8),
                    minHeight: 5),
                trailing: const Icon(Icons.chevron_right, color: N.muted))
        ])),
        gap,
        const Text(
            'Histórico de demonstração · agregados estimados para apresentação.',
            style: TextStyle(fontSize: 11, color: N.muted))
      ]))
    ]);
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.onLogout});
  final VoidCallback? onLogout;
  @override
  Widget build(BuildContext context) {
    final s = NexusScope.of(context);
    return PageScroll(children: [
      const Heading('Perfil', subtitle: 'Seu hotel, do seu jeito.'),
      _ProfileHero(userName: s.userName, hotelName: s.hotelName),
      const Section('Sessão Supabase'),
      Surface(
          child: Column(children: [
        KeyValue('Email', s.userEmail.isEmpty ? '—' : s.userEmail),
        KeyValue('Hotel member', s.membershipRole.isEmpty ? '—' : s.membershipRole),
        KeyValue('Espaços no banco', '${s.databaseSpaceCount}'),
        KeyValue('Dispositivos no banco', '${s.databaseDeviceCount}'),
      ])),
      const Section('Preferências'),
      Surface(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: bodyColumn([
            _Setting(Icons.person_outline, 'Minha conta', 'Nome e acesso',
                () => editName(context, false)),
            _Setting(Icons.apartment_outlined, 'Configurações do hotel',
                s.hotelName, () => editName(context, true)),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary:
                    const Icon(Icons.notifications_outlined, color: N.wine),
                title:
                    const Text('Notificações', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Preferência local de alertas',
                    style: TextStyle(fontSize: 11, color: N.muted)),
                value: s.notifications,
                onChanged: (v) => s.updatePreferences(notify: v)),
          ])),
      const Section('Demonstração'),
      Surface(
          onTap: () => showSimulation(context),
          child: const Row(children: [
            Icon(Icons.tune_rounded, color: N.wine),
            SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Controle da simulação',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Cenários, conexão e estados das telas',
                      style: TextStyle(color: N.muted, fontSize: 11))
                ])),
            Icon(Icons.chevron_right, color: N.muted)
          ])),
      gap,
      const Surface(
          child: Column(children: [
        Brand(),
        SizedBox(height: 18),
        Text('Inteligência para cada espaço.',
            style: TextStyle(color: N.muted, fontSize: 13)),
        SizedBox(height: 8),
        Text('Versão 1.0 · Projeto SENAI',
            style: TextStyle(color: N.muted, fontSize: 11))
      ])),
      gap,
      Text(
          'Hotel, perfil, dispositivos registrados e leituras vêm do Supabase. Os demais cenários são demonstrativos; preferências ficam na sessão.',
          style: TextStyle(fontSize: 11, color: N.muted)),
      if (onLogout != null) ...[
        gap,
        Surface(
            onTap: onLogout,
            child: const Row(children: [
              Icon(Icons.logout_rounded, color: N.wine),
              SizedBox(width: 13),
              Text('Sair da conta',
                  style: TextStyle(color: N.wine, fontWeight: FontWeight.w600))
            ]))
      ]
    ]);
  }
}

class _Setting extends StatelessWidget {
  const _Setting(this.icon, this.title, this.subtitle, this.action);
  final IconData icon;
  final String title, subtitle;
  final VoidCallback action;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
          color: Colors.transparent,
          child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: action,
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                            color: N.canvas,
                            borderRadius: BorderRadius.circular(14)),
                        child: Icon(icon, color: N.wine, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(subtitle,
                              style:
                                  const TextStyle(fontSize: 10, color: N.muted))
                        ])),
                    Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                            color: N.canvas, shape: BoxShape.circle),
                        child: const Icon(Icons.chevron_right_rounded,
                            color: N.rose, size: 19))
                  ])))));
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.userName, required this.hotelName});
  final String userName, hotelName;
  @override
  Widget build(BuildContext context) {
    final initials = userName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    return ClipRRect(
        borderRadius: BorderRadius.circular(N.radius),
        child: SizedBox(
            height: 260,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              Semantics(
                  image: true,
                  label: 'Lobby do hotel ao entardecer',
                  child: Image.asset('assets/images/lobby-evening.png',
                      fit: BoxFit.cover, alignment: const Alignment(0.72, 0))),
              const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                Color(0xE62E1D24),
                Color(0x783B252C),
                Color(0x252E1D24)
              ], begin: Alignment.bottomLeft, end: Alignment.topRight))),
              Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Brand(dark: true),
                          const Spacer(),
                          GlassPanel(
                              padding: const EdgeInsets.all(9),
                              child: IconButton(
                                  tooltip: 'Editar meu nome',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                      width: 23, height: 23),
                                  onPressed: () => editName(context, false),
                                  icon: const Icon(Icons.edit_outlined,
                                      color: Colors.white, size: 17)))
                        ]),
                        GlassPanel(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            child: Row(children: [
                              CircleAvatar(
                                  radius: 25,
                                  backgroundColor: N.peach,
                                  child: Text(initials,
                                      style: const TextStyle(
                                          color: N.wine,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(userName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(hotelName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11)),
                                  ])),
                              const SizedBox(width: 7),
                              const Pill('Admin',
                                  dark: true,
                                  icon: Icons.verified_user_outlined)
                            ]))
                      ]))
            ])));
  }
}

Future<void> editName(BuildContext context, bool hotel) async {
  final store = NexusScope.of(context);
  final controller =
      TextEditingController(text: hotel ? store.hotelName : store.userName);
  final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
              title: Text(hotel ? 'Nome do hotel' : 'Minha conta'),
              content: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 40,
                  decoration:
                      InputDecoration(labelText: hotel ? 'Hotel' : 'Nome')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        Navigator.pop(c, controller.text.trim());
                      }
                    },
                    child: const Text('Salvar'))
              ]));
  if (result != null) {
    store.updatePreferences(
        hotel: hotel ? result : null, user: hotel ? null : result);
  }
  // O controller permanece vivo até o fechamento da animação do diálogo.
}

void showSimulation(BuildContext context) {
  final store = NexusScope.of(context);
  showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: N.canvas,
      builder: (context) => AnimatedBuilder(
          animation: store,
          builder: (context, _) => SafeArea(
              child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * .78,
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                      child: bodyColumn([
                        const Heading('Simulação',
                            subtitle:
                                'Explore condições reais, com dados de demonstração.'),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Atualização automática'),
                            subtitle: const Text(
                                'Novas leituras a cada 6 segundos',
                                style: TextStyle(fontSize: 12)),
                            value: !store.paused,
                            onChanged: (v) => store.setPaused(!v)),
                        const Section('Cenários'),
                        ResponsiveGrid(minWidth: 130, children: [
                          for (final entry in const {
                            DemoScenario.normal: 'Tudo normal',
                            DemoScenario.offline: 'ESP32 offline',
                            DemoScenario.heat: 'Temperatura alta',
                            DemoScenario.door: 'Alternar porta',
                            DemoScenario.presence: 'Alternar presença',
                            DemoScenario.light: 'Alterar iluminação'
                          }.entries)
                            OutlinedButton(
                                onPressed: () => store.applyScenario(entry.key),
                                style: OutlinedButton.styleFrom(
                                    backgroundColor: store.scenario == entry.key
                                        ? N.line
                                        : Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16)),
                                child: Text(entry.value,
                                    style: const TextStyle(fontSize: 11)))
                        ]),
                        const Section('Estados da interface'),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final entry in const {
                            ViewState.normal: 'Normal',
                            ViewState.loading: 'Carregando',
                            ViewState.empty: 'Vazio',
                            ViewState.offline: 'Sem conexão',
                            ViewState.error: 'Erro'
                          }.entries)
                            ChoiceChip(
                                label: Text(entry.value),
                                selected: store.state == entry.key,
                                onSelected: (_) => store.setState(entry.key))
                        ]),
                        const SizedBox(height: 24),
                        const Text(
                            'Offline preserva a última leitura. Cenários são compartilhados por todas as telas. O estado de carregamento volta ao normal automaticamente.',
                            style: TextStyle(
                                fontSize: 12, color: N.muted, height: 1.6)),
                        const SizedBox(height: 18),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Ver no aplicativo'))),
                      ]))))));
}

class EnvironmentRing extends StatelessWidget {
  const EnvironmentRing(
      {super.key,
      required this.label,
      required this.value,
      required this.maximum,
      required this.unit,
      required this.color,
      this.decimals = 0});
  final String label, unit;
  final double value, maximum;
  final Color color;
  final int decimals;
  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
            width: 78,
            height: 78,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                      tween: Tween(end: (value / maximum).clamp(0, 1)),
                      duration: Duration(
                          milliseconds: MediaQuery.disableAnimationsOf(context)
                              ? 0
                              : 800),
                      builder: (context, v, _) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 5,
                          strokeCap: StrokeCap.round,
                          color: color,
                          backgroundColor: N.canvas))),
              Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedNumber(value,
                    decimals: decimals,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.6)),
                Text(unit, style: const TextStyle(fontSize: 10, color: N.muted))
              ])
            ])),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontSize: 10, color: N.muted))
      ]);
}
