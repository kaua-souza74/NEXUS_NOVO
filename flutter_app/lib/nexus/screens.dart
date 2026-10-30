import 'package:flutter/material.dart';
import 'design.dart';
import 'hotel_viewer.dart';
import 'store.dart';
import 'app.dart' show Brand;

const gap = SizedBox(height: 16);
const _physicalDeviceId = 'ESP32-001';
const _physicalDeviceTopic = 'nexus/vista-real/quarto-101/ESP32-001/readings';

String _deviceTitle(DeviceData device) =>
    device.id == _physicalDeviceId ? '001' : device.id;

Widget bodyColumn(List<Widget> children) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
Widget detailBody(List<Widget> children) => Scaffold(
  body: SafeArea(child: PageScroll(children: children)),
);

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onTab});
  final ValueChanged<int> onTab;
  @override
  Widget build(BuildContext context) {
    final s = NexusScope.of(context);
    return PageScroll(
      key: const PageStorageKey('home'),
      horizontalPadding: 8,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/brand/nexus_logo.png',
                width: 44,
                height: 44,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXUS',
                  style: TextStyle(
                    color: N.wine,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.6,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'GESTÃO HOTELEIRA',
                  style: TextStyle(
                    color: N.muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: N.line.withValues(alpha: .8)),
                boxShadow: [
                  BoxShadow(
                    color: N.wine.withValues(alpha: .06),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SizedBox(
                width: 50,
                height: 50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Ver alertas',
                      onPressed: () => onTab(3),
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                    if (s.activeAlerts > 0)
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            color: N.red,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${s.activeAlerts}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DataGate(
          child: bodyColumn([
            Enter(
              child: Surface(
                dark: true,
                backgroundImage: 'assets/images/lobby-evening.png',
                padding: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: bodyColumn([
                    Row(
                      children: [
                        Pill(
                          s.databaseRealtimeConnected
                              ? 'ATUALIZADO AGORA'
                              : s.state == ViewState.offline
                              ? 'ÚLTIMA LEITURA'
                              : s.paused
                              ? 'PAUSADO'
                              : s.databaseSyncedAt != null
                              ? 'DADOS ATUALIZADOS'
                              : 'ACOMPANHAMENTO',
                          dark: true,
                        ),
                        const Spacer(),
                        Text(
                          timeLabel(s.databaseSyncedAt ?? s.updatedAt),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    Text(
                      s.hotelName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -.7,
                      ),
                    ),
                    const SizedBox(height: 18),
                    AnimatedNumber(
                      s.spaces.length.toDouble(),
                      style: const TextStyle(
                        fontSize: 82,
                        height: 1.05,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -5,
                      ),
                    ),
                    const Text(
                      'espaços monitorados',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 22),
                    Pill(
                      s.databaseError != null
                          ? 'Não foi possível atualizar'
                          : s.databaseRealtimeConnected
                          ? 'Recebendo leituras'
                          : s.databaseSyncedAt != null
                          ? 'Leituras atualizadas'
                          : 'Aguardando sincronização',
                      dark: true,
                      icon: s.databaseError != null
                          ? Icons.error_outline
                          : s.databaseRealtimeConnected
                          ? Icons.bolt_rounded
                          : Icons.check_circle_outline,
                    ),
                    const SizedBox(height: 25),
                    GlassPanel(
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _HeroStat(
                              '${s.onlineDevices}',
                              'Sensores online',
                              N.peach,
                            ),
                          ),
                          Expanded(
                            child: _HeroStat(
                              '${s.devices.length - s.onlineDevices}',
                              'Sem sinal',
                              Colors.white60,
                            ),
                          ),
                          Expanded(
                            child: _HeroStat(
                              '${s.recentReadingCount}',
                              'Leituras recentes',
                              const Color(0xFFF4B7A8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (s.showHotelViewer)
              _HomeAction(
                title: 'Visualizador do hotel',
                description: 'Planta e leituras dos sensores',
                icon: Icons.apartment_rounded,
                primary: true,
                onTap: () => openPage(context, const HotelViewerPage()),
              ),
            const Section('Acesso rápido'),
            Row(
              children: [
                _Quick('Espaços', Icons.grid_view_rounded, () => onTab(1)),
                _Quick('Dispositivos', Icons.sensors_rounded, () => onTab(2)),
                _Quick('Alertas', Icons.notifications_outlined, () => onTab(3)),
              ],
            ),
            Section(
              'Espaços ao vivo',
              action: 'Ver todos',
              onAction: () => onTab(1),
            ),
            SizedBox(
              height: 238,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth
                      .clamp(320.0, 460.0)
                      .toDouble();
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    separatorBuilder: (_, i) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final space = s.space(
                        ['pool', 'lobby', 'restaurant', 'parking'][i],
                      );
                      return SizedBox(
                        width: cardWidth,
                        child: SpaceCard(
                          space,
                          alert: s.alertsIn(space.id).isNotEmpty,
                          onTap: () => openPage(context, SpaceDetail(space.id)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Section(
              'Atividade do hotel',
              action: 'Analytics ↗',
              onAction: () => openPage(context, const AnalyticsPage()),
            ),
            Enter(
              index: 2,
              child: Surface(
                dark: true,
                onTap: () => openPage(context, const AnalyticsPage()),
                child: bodyColumn([
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ocupação agora',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                      Pill('Hoje', dark: true),
                    ],
                  ),
                  AnimatedNumber(
                    s.activity,
                    suffix: '%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 43,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.occupiedSpaces} espaços com presença detectada',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 22),
                  NexusChart(
                    values: s.activityHistory.map((v) => v * 100).toList(),
                    dark: true,
                    unit: '%',
                  ),
                ]),
              ),
            ),
            const Section('Equilíbrio dos ambientes'),
            Surface(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: EnvironmentRing(
                          label: 'Temperatura',
                          value: s.averageTemperature,
                          maximum: 40,
                          unit: '°C',
                          decimals: 1,
                          color: N.wine,
                        ),
                      ),
                      Expanded(
                        child: EnvironmentRing(
                          label: 'Umidade',
                          value: s.averageHumidity,
                          maximum: 100,
                          unit: '%',
                          color: N.rose,
                        ),
                      ),
                      Expanded(
                        child: EnvironmentRing(
                          label: 'Luminosidade',
                          value: s.averageLight,
                          maximum: 1200,
                          unit: 'raw',
                          color: N.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '${s.occupiedSpaces} espaços ocupados · médias dos sensores online',
                    style: const TextStyle(color: N.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String title, description;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : N.ink;
    final secondary = primary ? Colors.white70 : N.muted;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: primary ? null : Colors.white,
            gradient: primary ? N.gradient : null,
            border: primary ? null : Border.all(color: N.line),
            borderRadius: BorderRadius.circular(20),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: N.wine.withValues(alpha: .16),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 86),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primary
                        ? Colors.white.withValues(alpha: .14)
                        : N.canvas,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: primary ? Colors.white : N.wine),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: secondary, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: primary ? Colors.white : N.rose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat(this.value, this.label, this.color);
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 25,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 28,
          child: Center(
            child: Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                height: 1.25,
              ),
            ),
          ),
        ),
      ],
    ),
  );
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
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: N.wine, size: 24),
          ),
          const SizedBox(height: 9),
          Text(label, style: const TextStyle(fontSize: 11, color: N.muted)),
        ],
      ),
    ),
  );
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
        .where(
          (v) => switch (filter) {
            'Ocupados' => v.online && v.presence,
            'Livres' => v.online && !v.presence,
            'Em alerta' => s.alertsIn(v.id).isNotEmpty,
            'Offline' => !v.online,
            _ => true,
          },
        )
        .toList();
    return PageScroll(
      children: [
        Heading('Espaços', subtitle: '${s.spaces.length} espaços monitorados.'),
        const PhotoBanner(
          image: 'assets/images/hotel-corridor.png',
          eyebrow: 'Ambientes conectados',
          title: 'Cada espaço, em perspectiva.',
          subtitle: 'Condições atuais e presença em um só lugar.',
        ),
        gap,
        FilterPills(
          items: const ['Todos', 'Ocupados', 'Livres', 'Em alerta', 'Offline'],
          selected: filter,
          onChanged: (v) => setState(() => filter = v),
        ),
        const SizedBox(height: 22),
        DataGate(
          child: items.isEmpty
              ? const EmptyPanel(
                  icon: Icons.check_circle_outline,
                  title: 'Tudo tranquilo por aqui',
                  message: 'Nenhum espaço corresponde a este filtro.',
                )
              : ResponsiveGrid(
                  minWidth: 270,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Enter(
                        index: i,
                        child: SpaceCard(
                          items[i],
                          alert: s.alertsIn(items[i].id).isNotEmpty,
                          onTap: () =>
                              openPage(context, SpaceDetail(items[i].id)),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
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
        .where(
          (d) => switch (filter) {
            'Online' => d.online,
            'Offline' => !d.online,
            'Atenção' => s.alertsIn(d.spaceId).isNotEmpty,
            _ => true,
          },
        )
        .toList();
    items.sort((a, b) => a.id.compareTo(b.id));
    return PageScroll(
      children: [
        PhotoBanner(
          image: 'assets/images/iot-device-professional.png',
          eyebrow: '${s.devices.length} dispositivos cadastrados',
          title: 'Dispositivos',
          subtitle: 'Conexões e leituras dos seus ambientes.',
          trailing: const Icon(
            Icons.sensors_rounded,
            color: Colors.white,
            size: 25,
          ),
          footer: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Expanded(
                  child: _DeviceStat(
                    '${s.onlineDevices}',
                    'Sensores online',
                    N.peach,
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: Colors.white.withValues(alpha: .22),
                ),
                Expanded(
                  child: _DeviceStat(
                    '${s.devices.length - s.onlineDevices}',
                    'Sem sinal',
                    Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        gap,
        FilterPills(
          items: const ['Todos', 'Online', 'Offline', 'Atenção'],
          selected: filter,
          onChanged: (v) => setState(() => filter = v),
        ),
        const SizedBox(height: 22),
        DataGate(
          child: items.isEmpty
              ? const EmptyPanel(
                  icon: Icons.sensors_off,
                  title: 'Nenhum dispositivo',
                  message: 'Experimente outro filtro.',
                )
              : ResponsiveGrid(
                  minWidth: 280,
                  children: items.map((d) => DeviceCard(d)).toList(),
                ),
        ),
      ],
    );
  }
}

class DeviceCard extends StatelessWidget {
  const DeviceCard(this.device, {super.key});
  final DeviceData device;
  @override
  Widget build(BuildContext context) {
    final s = NexusScope.of(context);
    final room = s.space(device.spaceId);
    return Surface(
      padding: EdgeInsets.zero,
      onTap: () => openPage(context, DeviceDetail(device.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 124,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/iot-device-professional.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(
                        color: N.wine,
                        child: Icon(
                          Icons.memory_rounded,
                          color: N.peach,
                          size: 38,
                        ),
                      ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x160E0B0C), Color(0xB52E1D24)],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 14,
                  child: Row(
                    children: [
                      Text(
                        'DISPOSITIVO ${_deviceTitle(device)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Pill(
                        device.online ? 'Online' : 'Offline',
                        dark: true,
                        icon: device.online
                            ? Icons.check_circle_outline
                            : Icons.cloud_off_outlined,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 12,
                  child: Text(
                    room.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 8)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _deviceTitle(device),
                        style: const TextStyle(
                          color: N.ink,
                          fontSize: 20,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.4,
                        ),
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: N.canvas,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_outward_rounded,
                        color: N.wine,
                        size: 17,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      device.online ? Icons.circle : Icons.circle_outlined,
                      size: 8,
                      color: device.online ? N.green : N.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      device.online ? 'Conectado' : 'Sem comunicação',
                      style: TextStyle(
                        color: device.online ? N.green : N.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      ageLabel(device.lastSeen),
                      style: const TextStyle(color: N.muted, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _DeviceReading(
                        'Temp.',
                        '${room.temperature.toStringAsFixed(1)} °C',
                        Icons.thermostat_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DeviceReading(
                        'Umidade',
                        '${room.humidity.round()}%',
                        Icons.water_drop_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DeviceReading(
                        'Luz · raw',
                        '${room.light}',
                        Icons.light_mode_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceReading extends StatelessWidget {
  const _DeviceReading(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
    decoration: BoxDecoration(
      color: N.canvas,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: N.wine, size: 15),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: N.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: N.muted, fontSize: 9),
        ),
      ],
    ),
  );
}

class _DeviceStat extends StatelessWidget {
  const _DeviceStat(this.value, this.label, this.color);
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 23,
          height: 1,
          fontWeight: FontWeight.w600,
          letterSpacing: -.6,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
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
        .where(
          (a) =>
              a.resolved == (status == 'Resolvidos') &&
              (level == 'Todos' || alertLevelLabel(a.level) == level),
        )
        .toList();
    return PageScroll(
      children: [
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
            size: 24,
          ),
          footer: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Expanded(
                  child: _DeviceStat(
                    '${s.activeAlerts}',
                    'Ativos agora',
                    const Color(0xFFF4B7A8),
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: Colors.white.withValues(alpha: .22),
                ),
                Expanded(
                  child: _DeviceStat(
                    '${s.alerts.length - s.activeAlerts}',
                    'Resolvidos',
                    Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        gap,
        FilterPills(
          items: const ['Ativos', 'Resolvidos'],
          selected: status,
          onChanged: (v) => setState(() => status = v),
        ),
        gap,
        FilterPills(
          items: const ['Todos', 'Crítico', 'Atenção', 'Informativo'],
          selected: level,
          onChanged: (v) => setState(() => level = v),
        ),
        const SizedBox(height: 22),
        DataGate(
          child: items.isEmpty
              ? const EmptyPanel(
                  icon: Icons.check_circle_outline,
                  title: 'Nenhum alerta por aqui',
                  message: 'Os ambientes estão dentro das condições esperadas.',
                )
              : bodyColumn([
                  for (final a in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Surface(
                        onTap: () => openPage(context, AlertDetail(a.id)),
                        child: bodyColumn([
                          Row(
                            children: [
                              Pill(
                                a.resolved
                                    ? 'Resolvido'
                                    : alertLevelLabel(a.level),
                                color: a.resolved
                                    ? N.green
                                    : alertColor(a.level),
                              ),
                              const Spacer(),
                              Text(
                                ageLabel(a.detected),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: N.muted,
                                ),
                              ),
                            ],
                          ),
                          gap,
                          Text(
                            a.title,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${s.space(a.spaceId).name} · ${a.deviceId}',
                            style: const TextStyle(
                              color: N.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            a.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: N.muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              Text(
                                'Ver ocorrência',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: N.wine,
                                ),
                              ),
                              Spacer(),
                              Icon(
                                Icons.arrow_outward,
                                size: 17,
                                color: N.wine,
                              ),
                            ],
                          ),
                        ]),
                      ),
                    ),
                ]),
        ),
      ],
    );
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
            backgroundImage: spaceImagePath(v),
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 356,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -.7,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                v.type,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            spaceIcon(v.id),
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Pill(
                          v.online ? 'Monitoramento ativo' : 'Sem comunicação',
                          dark: true,
                        ),
                        const Spacer(),
                        Text(
                          v.presence ? 'Ocupado' : 'Livre',
                          style: TextStyle(
                            color: v.presence
                                ? const Color(0xFFFFB8B5)
                                : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedNumber(
                      v.temperature,
                      decimals: 1,
                      suffix: '°C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 62,
                        height: 1,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      v.online
                          ? 'Atualizado ${timeLabel(v.lastReading)}'
                          : 'Última leitura ${ageLabel(v.lastReading)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 18),
                    GlassPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _HeroStat(
                              '${v.humidity.round()}%',
                              'Umidade',
                              Colors.white,
                            ),
                          ),
                          Expanded(
                            child: _HeroStat(
                              '${v.light} raw',
                              'Luminosidade',
                              Colors.white,
                            ),
                          ),
                          Expanded(
                            child: _HeroStat(
                              '${v.deviceCount}',
                              'Dispositivos',
                              Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Section('Sensores do ambiente'),
          ResponsiveGrid(
            children: [
              Metric(
                label: 'Umidade',
                value: v.humidity,
                unit: '%',
                icon: Icons.water_drop_outlined,
              ),
              Metric(
                label: 'Luminosidade',
                value: v.light.toDouble(),
                unit: ' raw',
                icon: Icons.light_mode_outlined,
              ),
            ],
          ),
          gap,
          ResponsiveGrid(
            children: [
              _StatusSensor(
                'Presença',
                v.presence ? 'Detectada' : 'Sem presença',
                Icons.person_outline,
                v.presence,
              ),
            ],
          ),
          const Section('Temperatura ao longo do tempo'),
          FilterPills(
            items: const ['1H', '6H', '24H', '7D'],
            selected: period,
            onChanged: (p) => setState(() => period = p),
          ),
          gap,
          Surface(
            child: NexusChart(
              key: ValueKey(period),
              values: s.series('Temperatura', period, spaceId: v.id),
              unit: '°C',
              labels: periodLabels(period),
            ),
          ),
          const Section('Dispositivos conectados'),
          for (final d in s.devicesIn(v.id))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DeviceCard(d),
            ),
          const Section('Eventos recentes'),
          Surface(
            child: bodyColumn([
              for (final e in v.events.where((event) => event.kind != 'door'))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: N.canvas,
                    child: Icon(eventIcon(e.kind), color: N.wine, size: 18),
                  ),
                  title: Text(e.message, style: const TextStyle(fontSize: 12)),
                  subtitle: Text(
                    ageLabel(e.time),
                    style: const TextStyle(fontSize: 10, color: N.muted),
                  ),
                ),
            ]),
          ),
        ]),
      ),
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
    padding: EdgeInsets.zero,
    child: SizedBox(
      height: 174,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: N.wine, size: 21),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  height: 22,
                  child: Center(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: N.muted),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

List<String> periodLabels(String period) => switch (period) {
  '1H' => ['−60 min', '−40 min', '−20 min', 'Agora'],
  '6H' => ['−6 h', '−4 h', '−2 h', 'Agora'],
  '7D' => ['−7d', '−4d', '−2d', 'Hoje'],
  _ => ['−24h', '−16h', '−8h', 'Agora'],
};

class DeviceDetail extends StatelessWidget {
  const DeviceDetail(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context) {
    final s = NexusScope.of(context);
    final d = s.device(id), v = s.space(d.spaceId);
    return detailBody([
      Heading(_deviceTitle(d), back: true, subtitle: v.name),
      DataGate(
        child: bodyColumn([
          Surface(
            dark: true,
            backgroundImage: 'assets/images/iot-device-professional.png',
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: bodyColumn([
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(
                        Icons.memory_rounded,
                        color: N.peach,
                        size: 27,
                      ),
                    ),
                    const Spacer(),
                    Pill(d.online ? 'Online' : 'Offline', dark: true),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  d.online ? 'Conectado à ${v.name}' : 'Conexão interrompida',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Última comunicação ${ageLabel(d.lastSeen)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ]),
            ),
          ),
          const Section('Leituras dos sensores'),
          ResponsiveGrid(
            children: [
              Metric(
                label: d.id == _physicalDeviceId
                    ? 'DHT11 · Temperatura'
                    : 'DHT22 · Temperatura',
                value: v.temperature,
                decimals: 1,
                unit: '°C',
                icon: Icons.thermostat_outlined,
              ),
              Metric(
                label: d.id == _physicalDeviceId
                    ? 'DHT11 · Umidade'
                    : 'DHT22 · Umidade',
                value: v.humidity,
                unit: '%',
                icon: Icons.water_drop_outlined,
              ),
              Metric(
                label: 'LDR · Luminosidade',
                value: v.light.toDouble(),
                unit: ' raw',
                icon: Icons.light_mode_outlined,
              ),
              _StatusSensor(
                d.id == _physicalDeviceId
                    ? 'Botão · Presença'
                    : 'PIR · Presença',
                v.presence ? 'Detectada' : 'Ausente',
                Icons.person_outline,
                v.presence,
              ),
            ],
          ),
          gap,
          const Section('Histórico de temperatura'),
          Surface(
            child: NexusChart(values: v.history, unit: '°C'),
          ),
          const Section('Informações técnicas'),
          Surface(
            child: bodyColumn([
              KeyValue(
                'Modelo',
                d.id == _physicalDeviceId
                    ? 'UNO R4 WiFi'
                    : d.databaseBacked
                    ? 'ESP32'
                    : 'ESP32 DevKit V1',
              ),
              KeyValue('Firmware', 'Não informado'),
              KeyValue('Protocolo', 'MQTT'),
              KeyValue(
                'Tópico',
                d.id == _physicalDeviceId
                    ? _physicalDeviceTopic
                    : d.databaseBacked
                    ? 'nexus/vista-real/piscina/${d.id}/readings'
                    : '—',
              ),
              KeyValue(
                'Intervalo',
                d.databaseBacked ? 'Conforme dispositivo' : '—',
              ),
              KeyValue(
                'Mensagens recebidas',
                d.databaseBacked ? '${d.messages}' : '—',
              ),
              KeyValue('Sinal Wi-Fi', 'Não informado'),
              KeyValue('Saúde', d.online ? 'Operacional' : 'Verificar conexão'),
            ]),
          ),
          gap,
          OutlinedButton.icon(
            onPressed: () => openPage(context, SpaceDetail(v.id)),
            icon: const Icon(Icons.grid_view_rounded),
            label: const Text('Ver espaço'),
          ),
        ]),
      ),
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
              Row(
                children: [
                  Pill(
                    a.resolved ? 'Resolvido' : alertLevelLabel(a.level),
                    dark: true,
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: N.peach,
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                a.title,
                style: const TextStyle(
                  fontSize: 29,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                a.description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ]),
          ),
          const Section('Contexto do alerta'),
          Surface(
            child: bodyColumn([
              KeyValue('Espaço', v.name),
              KeyValue('Dispositivo', a.deviceId),
              KeyValue(
                'Detectado',
                '${a.detected.day}/${a.detected.month} · ${timeLabel(a.detected)}',
              ),
              KeyValue('Status', a.resolved ? 'Resolvido localmente' : 'Ativo'),
              KeyValue(
                'Temperatura atual',
                '${v.temperature.toStringAsFixed(1)} °C',
              ),
            ]),
          ),
          const Section('Leituras próximas à ocorrência'),
          Surface(
            child: NexusChart(values: v.history, unit: '°C'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: a.resolved ? null : () => s.resolve(a.id),
              icon: Icon(a.resolved ? Icons.check : Icons.task_alt),
              label: Text(
                a.resolved ? 'Alerta resolvido' : 'Marcar como resolvido',
              ),
            ),
          ),
          gap,
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => openPage(context, SpaceDetail(v.id)),
                  child: const Text('Ver espaço'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => openPage(context, DeviceDetail(a.deviceId)),
                  child: const Text('Ver dispositivo'),
                ),
              ),
            ],
          ),
          gap,
          const Text(
            'As ações são mantidas durante esta sessão.',
            style: TextStyle(color: N.muted, fontSize: 11),
          ),
        ]),
      ),
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
      const Heading(
        'Analytics',
        back: true,
        subtitle: 'Transforme leituras em uma visão do hotel.',
      ),
      FilterPills(
        items: const ['Hoje', '7 dias', '30 dias'],
        selected: period,
        onChanged: (v) => setState(() => period = v),
      ),
      const SizedBox(height: 22),
      DataGate(
        child: bodyColumn([
          Surface(
            dark: true,
            child: bodyColumn([
              const Text(
                'Atividade dos ambientes',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              AnimatedNumber(
                s.periodAverage('Ocupação', period),
                suffix: '%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  letterSpacing: -3,
                ),
              ),
              const Text(
                'ocupação média estimada no período',
                style: TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 24),
              NexusChart(
                values: s.series('Ocupação', period),
                dark: true,
                unit: '%',
                labels: period == 'Hoje'
                    ? const ['−24h', '−16h', '−8h', 'Agora']
                    : period == '7 dias'
                    ? const ['−7d', '−4d', '−2d', 'Hoje']
                    : const ['−30d', '−20d', '−10d', 'Hoje'],
              ),
            ]),
          ),
          const Section('Condições e operação'),
          ResponsiveGrid(
            children: [
              Metric(
                label: 'Temperatura média',
                value: s.periodAverage('Temperatura', period),
                decimals: 1,
                unit: '°C',
                icon: Icons.thermostat_outlined,
              ),
              Metric(
                label: 'Umidade média',
                value: s.periodAverage('Umidade', period),
                unit: '%',
                icon: Icons.water_drop_outlined,
              ),
              Metric(
                label: 'Dispositivos online',
                value: s.onlineDevices / s.devices.length * 100,
                unit: '%',
                icon: Icons.sensors,
              ),
              Metric(
                label: 'Alertas no período',
                value:
                    (period == 'Hoje'
                            ? s.alerts.length
                            : period == '7 dias'
                            ? 34
                            : 126)
                        .toDouble(),
                icon: Icons.notifications_outlined,
              ),
            ],
          ),
          const Section('Explore as leituras'),
          FilterPills(
            items: const ['Ocupação', 'Temperatura', 'Umidade'],
            selected: metric,
            onChanged: (v) => setState(() => metric = v),
          ),
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
              unit: metric == 'Temperatura' ? '°C' : '%',
            ),
          ),
          const Section('Espaços mais ativos'),
          Surface(
            child: bodyColumn([
              for (final id in ['lobby', 'restaurant', 'pool', 'conference'])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => openPage(context, SpaceDetail(id)),
                  leading: CircleAvatar(
                    backgroundColor: N.canvas,
                    child: Icon(spaceIcon(id), color: N.wine, size: 20),
                  ),
                  title: Text(
                    s.space(id).name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: LinearProgressIndicator(
                    value: id == 'lobby'
                        ? 0.92
                        : id == 'restaurant'
                        ? 0.81
                        : 0.74,
                    color: N.rose,
                    backgroundColor: N.canvas,
                    borderRadius: BorderRadius.circular(8),
                    minHeight: 5,
                  ),
                  trailing: const Icon(Icons.chevron_right, color: N.muted),
                ),
            ]),
          ),
          gap,
          const Text(
            'Períodos anteriores são estimados com base nas leituras disponíveis.',
            style: TextStyle(fontSize: 11, color: N.muted),
          ),
        ]),
      ),
    ]);
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.onLogout});
  final VoidCallback? onLogout;
  @override
  Widget build(BuildContext context) {
    final s = NexusScope.of(context);
    return PageScroll(
      children: [
        Heading(
          'Perfil',
          subtitle: 'Seu hotel, do seu jeito.',
          trailing: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: N.wine,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: N.wine.withValues(alpha: .16),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        _ProfileHero(userName: s.userName, hotelName: s.hotelName),
        const Section('Preferências'),
        Surface(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: bodyColumn([
            _Setting(
              Icons.person_outline,
              'Minha conta',
              'Nome e acesso',
              () => editName(context, false),
            ),
            _Setting(
              Icons.apartment_outlined,
              'Configurações do hotel',
              s.hotelName,
              () => editName(context, true),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(
                Icons.notifications_outlined,
                color: N.wine,
              ),
              title: const Text('Notificações', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'Preferência local de alertas',
                style: TextStyle(fontSize: 11, color: N.muted),
              ),
              value: s.notifications,
              onChanged: (v) => s.updatePreferences(notify: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.speed_rounded, color: N.wine),
              title: const Text(
                'Reduzir animações',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                'Deixar a interface mais leve',
                style: TextStyle(fontSize: 11, color: N.muted),
              ),
              value: s.reduceMotion,
              onChanged: (v) => s.updatePreferences(motion: v),
            ),
          ]),
        ),
        gap,
        const Surface(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Brand(),
                    Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'NEXUS 1.0',
                          style: TextStyle(
                            color: N.wine,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .8,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Projeto SENAI',
                          style: TextStyle(color: N.muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.sensors_outlined, color: N.rose, size: 18),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Monitoramento de ambientes e sensores.',
                        style: TextStyle(color: N.muted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (onLogout != null) ...[
          gap,
          Surface(
            padding: EdgeInsets.zero,
            onTap: onLogout,
            child: const SizedBox(
              height: 72,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: N.canvas,
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(Icons.logout_rounded, color: N.wine),
                      ),
                    ),
                    SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sair da conta',
                            style: TextStyle(
                              color: N.wine,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Encerrar esta sessão',
                            style: TextStyle(color: N.muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: N.muted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
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
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: N.canvas,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: N.wine, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 10, color: N.muted),
                    ),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: N.canvas,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: N.rose,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              image: true,
              label: 'Lobby do hotel ao entardecer',
              child: Image.asset(
                'assets/images/lobby-evening.png',
                fit: BoxFit.cover,
                alignment: const Alignment(0.72, 0),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xE62E1D24),
                    Color(0x783B252C),
                    Color(0x252E1D24),
                  ],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Brand(dark: true),
                      const Spacer(),
                      GlassPanel(
                        padding: const EdgeInsets.all(9),
                        child: IconButton(
                          tooltip: 'Editar meu nome',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 23,
                            height: 23,
                          ),
                          onPressed: () => editName(context, false),
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  GlassPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: N.peach,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: N.wine,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hotelName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Pill(
                          'Admin',
                          dark: true,
                          icon: Icons.verified_user_outlined,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> editName(BuildContext context, bool hotel) async {
  final store = NexusScope.of(context);
  final controller = TextEditingController(
    text: hotel ? store.hotelName : store.userName,
  );
  final result = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(hotel ? 'Nome do hotel' : 'Minha conta'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 40,
        decoration: InputDecoration(labelText: hotel ? 'Hotel' : 'Nome'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(c, controller.text.trim());
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
  if (result != null) {
    store.updatePreferences(
      hotel: hotel ? result : null,
      user: hotel ? null : result,
    );
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
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Material(
        color: N.canvas,
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .78,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: bodyColumn([
                const Heading(
                  'Simulação',
                  subtitle: 'Explore diferentes condições dos ambientes.',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Atualização automática'),
                  subtitle: const Text(
                    'Novas leituras a cada 6 segundos',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: !store.paused,
                  onChanged: (v) {
                    store.setPaused(!v);
                    setSheetState(() {});
                  },
                ),
                const Section('Cenários'),
                ResponsiveGrid(
                  minWidth: 130,
                  children: [
                    for (final entry in const {
                      DemoScenario.normal: 'Tudo normal',
                      DemoScenario.offline: 'ESP32 offline',
                      DemoScenario.heat: 'Temperatura alta',
                      DemoScenario.presence: 'Alternar presença',
                      DemoScenario.light: 'Alterar iluminação',
                    }.entries)
                      OutlinedButton(
                        onPressed: () {
                          store.applyScenario(entry.key);
                          setSheetState(() {});
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: store.scenario == entry.key
                              ? N.line
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Os cenários alteram somente valores locais de visualização e não gravam leituras conectadas.',
                  style: TextStyle(fontSize: 12, color: N.muted, height: 1.6),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Ver no aplicativo'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}

class EnvironmentRing extends StatelessWidget {
  const EnvironmentRing({
    super.key,
    required this.label,
    required this.value,
    required this.maximum,
    required this.unit,
    required this.color,
    this.decimals = 0,
  });
  final String label, unit;
  final double value, maximum;
  final Color color;
  final int decimals;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: 78,
        height: 78,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: (value / maximum).clamp(0, 1)),
                duration: Duration(
                  milliseconds: MediaQuery.disableAnimationsOf(context)
                      ? 0
                      : 800,
                ),
                builder: (context, v, _) => CircularProgressIndicator(
                  value: v,
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  color: color,
                  backgroundColor: N.canvas,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedNumber(
                  value,
                  decimals: decimals,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.6,
                  ),
                ),
                Text(
                  unit,
                  style: const TextStyle(fontSize: 10, color: N.muted),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(label, style: const TextStyle(fontSize: 10, color: N.muted)),
    ],
  );
}
