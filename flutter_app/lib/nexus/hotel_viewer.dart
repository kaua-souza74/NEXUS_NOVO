import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design.dart';
import 'store.dart';

class HotelViewerPage extends StatefulWidget {
  const HotelViewerPage({super.key});

  @override
  State<HotelViewerPage> createState() => _HotelViewerPageState();
}

class _HotelViewerPageState extends State<HotelViewerPage> {
  static const _planSize = Size(760, 507);
  static const _positions = <String, Offset>{
    'lobby': Offset(.13, .50),
    'test-bench': Offset(.36, .17),
    'parking': Offset(.49, .17),
    'kitchen': Offset(.69, .45),
    'outdoor': Offset(.17, .78),
    'restaurant': Offset(.68, .13),
    'garden': Offset(.49, .49),
    'conference': Offset(.31, .82),
    'gym': Offset(.52, .82),
    'pool': Offset(.82, .73),
    'spa': Offset(.93, .55),
    'storage': Offset(.91, .25),
    'laundry': Offset(.84, .43),
    'corridor': Offset(.61, .63),
  };

  final _transform = TransformationController();
  Timer? _refreshTimer;
  Size? _viewport;
  String? _selectedSpaceId;
  NexusStore? _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = NexusScope.of(context);
    if (!identical(store, _store)) {
      _store = store;
      _refreshTimer?.cancel();
      if (store.repository != null) {
        _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
          unawaited(store.refreshFromDatabase());
        });
        unawaited(store.refreshFromDatabase());
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _transform.dispose();
    super.dispose();
  }

  void _fit(Size viewport) {
    final scale = math
        .min(
          (viewport.width / _planSize.width).clamp(.32, 1.2),
          (viewport.height / _planSize.height).clamp(.32, 1.2),
        )
        .toDouble();
    final tx = (viewport.width - _planSize.width * scale) / 2;
    final ty = (viewport.height - _planSize.height * scale) / 2;
    final matrix = Matrix4.diagonal3Values(scale, scale, scale);
    matrix.setTranslationRaw(tx, ty, 0);
    _transform.value = matrix;
    _viewport = viewport;
  }

  void _zoom(double factor) {
    final viewport = _viewport;
    if (viewport == null) return;
    final current = _transform.value;
    final scale = current.getMaxScaleOnAxis();
    final next = (scale * factor).clamp(.32, 3.2).toDouble();
    final ratio = next / scale;
    final center = Offset(viewport.width / 2, viewport.height / 2);
    final tx = current.entry(0, 3);
    final ty = current.entry(1, 3);
    final matrix = Matrix4.diagonal3Values(next, next, next);
    matrix.setTranslationRaw(
      center.dx - (center.dx - tx) * ratio,
      center.dy - (center.dy - ty) * ratio,
      0,
    );
    _transform.value = matrix;
  }

  List<Map<String, dynamic>> _readingsFor(NexusStore store, SpaceData space) {
    final deviceIds = store.devices
        .where((device) => device.databaseBacked && device.spaceId == space.id)
        .map((device) => device.databaseId)
        .whereType<String>()
        .toSet();
    return store.databaseReadings
        .where((row) => deviceIds.contains(row['device_id']?.toString()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = NexusScope.of(context);
    final spaces = store.spaces;
    final physicalSpaceCount = spaces.where((space) => space.physical).length;
    final simulatedSpaceCount = spaces.length - physicalSpaceCount;
    final preferredId =
        spaces.where((space) => space.physical).firstOrNull?.id ??
        spaces.firstOrNull?.id;
    final selectedId = _selectedSpaceId ?? preferredId;
    final selected = spaces.where((space) => space.id == selectedId);
    final current = selected.isEmpty ? null : selected.first;
    final liveReadings = current == null || !current.physical
        ? <Map<String, dynamic>>[]
        : _readingsFor(store, current);
    final latestByType = <String, Map<String, dynamic>>{};
    for (final row in liveReadings) {
      latestByType.putIfAbsent(row['sensor_type']?.toString() ?? '', () => row);
    }
    final viewportHeight = MediaQuery.sizeOf(context).width < 600
        ? 310.0
        : 470.0;

    return Scaffold(
      body: SafeArea(
        child: PageScroll(
          horizontalPadding: 16,
          children: [
            _viewerHeader(context, store),
            Surface(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${spaces.length} áreas · $simulatedSpaceCount em simulação · $physicalSpaceCount com Arduino',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Leituras do Arduino a cada 8 s · arraste, aproxime e toque em uma área.',
                    style: TextStyle(color: N.muted, fontSize: 10),
                  ),
                  const SizedBox(height: 13),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final viewport = Size(
                        constraints.maxWidth,
                        viewportHeight,
                      );
                      if (_viewport != viewport) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _viewport != viewport) _fit(viewport);
                        });
                      }
                      return RepaintBoundary(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: ColoredBox(
                            color: const Color(0xFFF1E8DF),
                            child: SizedBox(
                              width: constraints.maxWidth,
                              height: viewportHeight,
                              child: InteractiveViewer(
                                transformationController: _transform,
                                constrained: false,
                                minScale: .32,
                                maxScale: 3.2,
                                boundaryMargin: const EdgeInsets.all(24),
                                child: SizedBox(
                                  width: _planSize.width,
                                  height: _planSize.height,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      RepaintBoundary(
                                        child: Image.asset(
                                          'assets/images/hotel-floorplan.png',
                                          fit: BoxFit.fill,
                                        ),
                                      ),
                                      for (
                                        var index = 0;
                                        index < spaces.length;
                                        index++
                                      )
                                        _planMarker(
                                          spaces[index],
                                          index,
                                          selectedId,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Spacer(),
                      IconButton.outlined(
                        tooltip: 'Afastar',
                        onPressed: () => _zoom(1 / 1.25),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      IconButton.outlined(
                        tooltip: 'Enquadrar planta',
                        onPressed: () {
                          final size = _viewport;
                          if (size != null) _fit(size);
                        },
                        icon: const Icon(Icons.center_focus_strong_rounded),
                      ),
                      IconButton.outlined(
                        tooltip: 'Aproximar',
                        onPressed: () => _zoom(1.25),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (current != null) ...[
              const Section('Área selecionada'),
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: N.canvas,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(spaceIcon(current.id), color: N.wine),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                current.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                !current.physical
                                    ? 'Simulação ativa · atualização em tempo real'
                                    : liveReadings.isEmpty
                                    ? 'Aguardando leitura do Arduino'
                                    : 'Leitura recebida ${ageLabel(current.lastReading)}',
                                style: const TextStyle(
                                  color: N.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Pill(
                          current.physical
                              ? liveReadings.isEmpty
                                    ? 'Aguardando Arduino'
                                    : current.online
                                    ? 'Arduino online'
                                    : 'Arduino offline'
                              : current.online
                              ? 'Simulação ativa'
                              : 'Simulação pausada',
                          color:
                              !current.online ||
                                  (current.physical && liveReadings.isEmpty)
                              ? N.muted
                              : N.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ResponsiveGrid(
                      minWidth: 135,
                      children: [
                        _ViewerReading(
                          'Temperatura',
                          current.physical
                              ? _numericValue(
                                  latestByType['temperature'],
                                  ' °C',
                                  1,
                                )
                              : _formatSimulatedValue(
                                  current.temperature,
                                  ' °C',
                                  1,
                                ),
                          Icons.thermostat_outlined,
                        ),
                        _ViewerReading(
                          'Umidade',
                          current.physical
                              ? _numericValue(latestByType['humidity'], '%')
                              : _formatSimulatedValue(current.humidity, '%'),
                          Icons.water_drop_outlined,
                        ),
                        _ViewerReading(
                          'Luminosidade',
                          current.physical
                              ? _numericValue(latestByType['light'], ' lx')
                              : _formatSimulatedValue(
                                  current.light.toDouble(),
                                  ' lx',
                                ),
                          Icons.light_mode_outlined,
                        ),
                        _ViewerReading(
                          'Presença',
                          current.physical
                              ? _booleanValue(latestByType['presence'])
                              : current.presence
                              ? 'Detectada'
                              : 'Não detectada',
                          Icons.person_outline,
                        ),
                        _ViewerReading(
                          'Porta',
                          current.physical
                              ? _booleanValue(latestByType['door'])
                              : current.doorOpen
                              ? 'Aberta'
                              : 'Fechada',
                          Icons.sensor_door_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _viewerHeader(BuildContext context, NexusStore store) {
    Widget action({
      required String tooltip,
      required IconData icon,
      required VoidCallback onPressed,
    }) =>
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            fixedSize: const Size(42, 42),
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            foregroundColor: N.wine,
            side: const BorderSide(color: N.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: Icon(icon, size: 19),
        );

    final back = action(
      tooltip: 'Voltar',
      icon: Icons.arrow_back_rounded,
      onPressed: () => Navigator.of(context).maybePop(),
    );
    final refresh = action(
      tooltip: 'Atualizar leituras',
      icon: Icons.refresh_rounded,
      onPressed: store.refreshFromDatabase,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visualizador do hotel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 24 : 28,
                height: 1.1,
                letterSpacing: -.8,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Planta interativa e leituras dos sensores',
              style: TextStyle(color: N.muted, fontSize: 12),
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [back, const Spacer(), refresh]),
                    const SizedBox(height: 12),
                    title,
                  ],
                )
              : Row(
                  children: [
                    back,
                    const SizedBox(width: 12),
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    refresh,
                  ],
                ),
        );
      },
    );
  }

  Widget _planMarker(SpaceData space, int index, String? selectedId) {
    final position =
        _positions[space.id] ??
        Offset(.17 + (index % 5) * .16, .28 + (index % 3) * .2);
    final selected = space.id == selectedId;
    return Positioned(
      left: position.dx * _planSize.width - 21,
      top: position.dy * _planSize.height - 21,
      child: Tooltip(
        message:
            '${space.name} · ${space.physical ? 'Arduino físico' : 'Simulação'}',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: selected ? N.wine : Colors.white,
              shape: CircleBorder(
                side: BorderSide(
                  color: selected ? Colors.white : N.wine,
                  width: 2,
                ),
              ),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _selectedSpaceId = space.id),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    spaceIcon(space.id),
                    size: 19,
                    color: selected ? Colors.white : N.wine,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: space.physical
                      ? N.peach
                      : space.online
                      ? N.green
                      : N.muted,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _numericValue(
  Map<String, dynamic>? row,
  String unit, [
  int decimals = 0,
]) {
  final raw = row?['value_numeric'];
  final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (value == null) return '—';
  return '${value.toStringAsFixed(decimals).replaceAll('.', ',')}$unit';
}

String _formatSimulatedValue(double value, String unit, [int decimals = 0]) =>
    '${value.toStringAsFixed(decimals).replaceAll('.', ',')}$unit';

String _booleanValue(Map<String, dynamic>? row) {
  final value = row?['value_boolean'];
  if (value is bool) return value ? 'Detectada' : 'Não detectada';
  return '—';
}

class _ViewerReading extends StatelessWidget {
  const _ViewerReading(this.label, this.value, this.icon);

  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Surface(
    padding: const EdgeInsets.all(13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: N.wine, size: 19),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: N.muted, fontSize: 11)),
      ],
    ),
  );
}
