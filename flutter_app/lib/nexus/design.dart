import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'store.dart';

abstract final class N {
  static const wine = Color(0xFF4F3139),
      deep = Color(0xFF2E1D24),
      rose = Color(0xFF92656B),
      peach = Color(0xFFD8B5A0);
  static const canvas = Color(0xFFF6F3F1),
      ink = Color(0xFF30252A),
      muted = Color(0xFF8B7D80),
      line = Color(0xFFE8DFDC);
  static const green = Color(0xFF527F69),
      amber = Color(0xFFAE7937),
      red = Color(0xFFB64D4E);
  static const radius = 28.0;
  static const gradient = LinearGradient(
      colors: [deep, wine, rose],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);
}

class NexusScope extends InheritedNotifier<NexusStore> {
  const NexusScope({super.key, required NexusStore store, required super.child})
      : super(notifier: store);
  static NexusStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NexusScope>()!.notifier!;
}

void openPage(BuildContext context, Widget page) {
  final reduced = NexusScope.of(context).reduceMotion;
  Navigator.of(context).push(PageRouteBuilder(
    transitionDuration: Duration(milliseconds: reduced ? 0 : 380),
    reverseTransitionDuration: Duration(milliseconds: reduced ? 0 : 280),
    pageBuilder: (context, a, b) => page,
    transitionsBuilder: (context, a, b, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: SlideTransition(
            position: Tween(begin: const Offset(0.04, 0), end: Offset.zero)
                .animate(
                    CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child)),
  ));
}

class PageScroll extends StatelessWidget {
  const PageScroll(
      {super.key,
      required this.children,
      this.controller,
      this.horizontalPadding = 22});
  final List<Widget> children;
  final ScrollController? controller;
  final double horizontalPadding;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      controller: controller,
      padding:
          EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 122),
      child: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children))));
}

class Heading extends StatelessWidget {
  const Heading(this.title,
      {super.key, this.subtitle, this.back = false, this.trailing});
  final String title;
  final String? subtitle;
  final bool back;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(children: [
        if (back)
          Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton.filledTonal(
                  tooltip: 'Voltar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded))),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.1)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: const TextStyle(fontSize: 13, color: N.muted))
          ]
        ])),
        if (trailing != null) trailing!,
      ]));
}

class Section extends StatelessWidget {
  const Section(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 14),
      child: Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6))),
        if (action != null)
          TextButton(
              onPressed: onAction,
              child: Text(action!,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)))
      ]));
}

class Surface extends StatelessWidget {
  const Surface(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20),
      this.dark = false,
      this.onTap,
      this.color,
      this.backgroundImage});
  final Widget child;
  final EdgeInsets padding;
  final bool dark;
  final VoidCallback? onTap;
  final Color? color;
  final String? backgroundImage;
  @override
  Widget build(BuildContext context) => TapScale(
      onTap: onTap,
      child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
              color: dark ? null : (color ?? Colors.white),
              gradient: dark && backgroundImage == null ? N.gradient : null,
              borderRadius: BorderRadius.circular(N.radius),
              border: dark
                  ? null
                  : Border.all(color: N.line.withValues(alpha: .68)),
              boxShadow: [
                BoxShadow(
                    color: N.wine.withValues(alpha: 0.045),
                    blurRadius: 25,
                    offset: const Offset(0, 9))
              ]),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(N.radius),
              child: Stack(children: [
                if (backgroundImage != null) ...[
                  Positioned.fill(
                      child: Image.asset(backgroundImage!, fit: BoxFit.cover)),
                  Positioned.fill(
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                    N.deep.withValues(alpha: .91),
                    N.wine.withValues(alpha: .76),
                    N.deep.withValues(alpha: .57)
                  ], begin: Alignment.bottomLeft, end: Alignment.topRight))))
                ],
                Padding(
                    padding: padding,
                    child:
                        Material(type: MaterialType.transparency, child: child))
              ]))));
}

class PhotoBanner extends StatelessWidget {
  const PhotoBanner(
      {super.key,
      required this.image,
      required this.eyebrow,
      required this.title,
      required this.subtitle,
      this.trailing,
      this.footer});
  final String image, eyebrow, title, subtitle;
  final Widget? trailing;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(N.radius),
      child: SizedBox(
          height: footer == null ? 190 : 242,
          width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            Semantics(
                image: true,
                label: eyebrow,
                child: Image.asset(image, fit: BoxFit.cover)),
            const DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
              Color(0xE62E1D24),
              Color(0x77331F25),
              Color(0x1A2E1D24)
            ], begin: Alignment.bottomLeft, end: Alignment.topRight))),
            Padding(
                padding: const EdgeInsets.all(21),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(children: [
                        Text(eyebrow.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                letterSpacing: 1.8,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (trailing != null) trailing!
                      ]),
                      const SizedBox(height: 7),
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              height: 1.08,
                              letterSpacing: -.6,
                              fontFamily: 'Georgia')),
                      const SizedBox(height: 6),
                      Text(subtitle,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      if (footer != null) ...[
                        const SizedBox(height: 14),
                        footer!
                      ]
                    ]))
          ])));
}

class GlassPanel extends StatelessWidget {
  const GlassPanel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(12)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
              padding: padding,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .24)),
                  boxShadow: [
                    BoxShadow(
                        color: N.deep.withValues(alpha: .10), blurRadius: 18)
                  ]),
              child: child)));
}

class TapScale extends StatefulWidget {
  const TapScale({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: widget.onTap,
      onTapDown:
          widget.onTap == null ? null : (_) => setState(() => down = true),
      onTapCancel:
          widget.onTap == null ? null : () => setState(() => down = false),
      onTapUp:
          widget.onTap == null ? null : (_) => setState(() => down = false),
      child: AnimatedScale(
          scale: down ? 0.982 : 1,
          duration: const Duration(milliseconds: 130),
          child: widget.child));
}

class Enter extends StatelessWidget {
  const Enter({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(
          milliseconds:
              MediaQuery.disableAnimationsOf(context) ? 0 : 420 + index * 45),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
              offset: Offset(0, (1 - value) * 18), child: child)),
      child: child);
}

class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber(this.value,
      {super.key, this.decimals = 0, this.suffix = '', this.style});
  final double value;
  final int decimals;
  final String suffix;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 650),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
          '${v.toStringAsFixed(decimals).replaceAll('.', ',')}$suffix',
          style: style ??
              const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1.4)));
}

class Pill extends StatelessWidget {
  const Pill(this.text,
      {super.key,
      this.color = N.green,
      this.dark = false,
      this.dot = false,
      this.icon});
  final String text;
  final Color color;
  final bool dark, dot;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.14)
              : color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(30)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[
          PulseDot(color: dark ? const Color(0xFFA7CFB7) : color),
          const SizedBox(width: 6)
        ],
        if (icon != null) ...[
          Icon(icon, size: 13, color: dark ? Colors.white : color),
          const SizedBox(width: 5)
        ],
        Text(text,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white : color))
      ]));
}

class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.color = N.green});
  final Color color;
  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: MediaQuery.disableAnimationsOf(context)
                  ? []
                  : [
                      BoxShadow(
                          color: widget.color.withValues(
                              alpha: 0.12 + controller.value * 0.14),
                          blurRadius: 4,
                          spreadRadius: controller.value * 2)
                    ])));
}

class FilterPills extends StatelessWidget {
  const FilterPills(
      {super.key,
      required this.items,
      required this.selected,
      required this.onChanged});
  final List<String> items;
  final String selected;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final label in items)
          Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                  selected: label == selected,
                  button: true,
                  child: GestureDetector(
                      onTap: () => onChanged(label),
                      child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 17, vertical: 12),
                          decoration: BoxDecoration(
                              color: label == selected ? N.wine : Colors.white,
                              borderRadius: BorderRadius.circular(30)),
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: label == selected
                                      ? Colors.white
                                      : N.muted))))))
      ]));
}

IconData spaceIcon(String id) => switch (id) {
      'lobby' => Icons.door_front_door_outlined,
      'room101' || 'room102' => Icons.bed_outlined,
      'gym' => Icons.fitness_center_outlined,
      'restaurant' => Icons.restaurant_outlined,
      'pool' => Icons.pool_outlined,
      'conference' => Icons.event_outlined,
      'garden' => Icons.yard_outlined,
      'spa' => Icons.spa_outlined,
      'storage' => Icons.inventory_2_outlined,
      'laundry' => Icons.local_laundry_service_outlined,
      _ => Icons.sensor_door_outlined
    };
IconData eventIcon(String kind) => switch (kind) {
      'presence' => Icons.person_outline,
      'door' => Icons.sensor_door_outlined,
      'temperature' => Icons.thermostat_outlined,
      'light' => Icons.light_mode_outlined,
      _ => Icons.wifi_outlined
    };
Color alertColor(AlertLevel level) => switch (level) {
      AlertLevel.critical => N.red,
      AlertLevel.warning => N.amber,
      AlertLevel.info => N.green
    };
String alertLevelLabel(AlertLevel level) => switch (level) {
      AlertLevel.critical => 'Crítico',
      AlertLevel.warning => 'Atenção',
      AlertLevel.info => 'Informativo'
    };

class SpaceHero extends StatelessWidget {
  const SpaceHero(this.space, {super.key, this.dark = false});
  final SpaceData space;
  final bool dark;
  @override
  Widget build(BuildContext context) => Hero(
      tag: 'space-${space.id}',
      child: Material(
          color: dark ? N.wine : const Color(0xFFF7F1EE),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: dark ? Colors.white12 : Colors.white,
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(spaceIcon(space.id),
                        color: dark ? Colors.white : N.wine, size: 23)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(space.name,
                          style: TextStyle(
                              color: dark ? Colors.white : N.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3)),
                      const SizedBox(height: 4),
                      Text(space.type,
                          style: TextStyle(
                              color: dark ? Colors.white60 : N.muted,
                              fontSize: 11))
                    ]))
              ]))));
}

class SpaceCard extends StatelessWidget {
  const SpaceCard(this.space,
      {super.key, required this.onTap, this.alert = false});
  final SpaceData space;
  final VoidCallback onTap;
  final bool alert;
  @override
  Widget build(BuildContext context) => Surface(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SpaceHero(space),
        const SizedBox(height: 14),
        Row(children: [
          Pill(
              !space.online
                  ? 'Offline'
                  : space.presence
                      ? 'Ocupado'
                      : 'Livre',
              color: !space.online
                  ? N.muted
                  : space.presence
                      ? N.green
                      : N.wine,
              dot: space.online),
          const SizedBox(width: 7),
          Pill(space.databaseBacked ? 'Supabase' : 'Demo',
              color: space.databaseBacked ? N.wine : N.muted),
          const Spacer(),
          if (alert) const Icon(Icons.error_outline, color: N.amber, size: 18)
        ]),
        const SizedBox(height: 13),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          AnimatedNumber(space.temperature,
              decimals: 1,
              suffix: '°',
              style: const TextStyle(
                  fontSize: 31,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1.5)),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
                '${space.deviceCount} ${space.deviceCount == 1 ? 'dispositivo' : 'dispositivos'}',
                style: const TextStyle(fontSize: 11, color: N.muted)),
            const SizedBox(height: 5),
            Text(
                space.online
                    ? 'Atualizado ${ageLabel(space.lastReading)}'
                    : 'Último dado ${ageLabel(space.lastReading)}',
                style: const TextStyle(fontSize: 10, color: N.muted))
          ])
        ])
      ]));
}

class Metric extends StatelessWidget {
  const Metric(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      this.unit = '',
      this.decimals = 0,
      this.note,
      this.dark = false});
  final String label, unit;
  final double value;
  final IconData icon;
  final int decimals;
  final String? note;
  final bool dark;
  @override
  Widget build(BuildContext context) => Surface(
      dark: dark,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: dark ? N.peach : N.wine, size: 21),
        const SizedBox(height: 20),
        AnimatedNumber(value,
            decimals: decimals,
            suffix: unit,
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w500,
                letterSpacing: -1.3,
                color: dark ? Colors.white : N.ink)),
        const SizedBox(height: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: dark ? Colors.white70 : N.muted)),
        if (note != null) ...[
          const SizedBox(height: 10),
          Text(note!,
              style: TextStyle(
                  fontSize: 10, color: dark ? Colors.white54 : N.muted))
        ]
      ]));
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid(
      {super.key,
      required this.children,
      this.minWidth = 150,
      this.spacing = 12});
  final List<Widget> children;
  final double minWidth, spacing;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final count = math.max(
            1, ((c.maxWidth + spacing) / (minWidth + spacing)).floor());
        final width = (c.maxWidth - spacing * (count - 1)) / count;
        return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: children
                .map((child) => SizedBox(width: width, child: child))
                .toList());
      });
}

class DataGate extends StatelessWidget {
  const DataGate(
      {super.key,
      required this.child,
      this.emptyTitle = 'Nenhum dado disponível'});
  final Widget child;
  final String emptyTitle;
  @override
  Widget build(BuildContext context) {
    final store = NexusScope.of(context);
    if (store.state == ViewState.loading) {
      return Column(
          children: List.generate(
              3,
              (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                      height: i == 0 ? 220 : 135,
                      decoration: BoxDecoration(
                          color: N.line,
                          borderRadius: BorderRadius.circular(28))))));
    }
    if (store.state == ViewState.error || store.state == ViewState.empty) {
      return EmptyPanel(
          icon: store.state == ViewState.error
              ? Icons.cloud_off_outlined
              : Icons.sensors_off_outlined,
          title: store.state == ViewState.error
              ? 'Não foi possível atualizar'
              : emptyTitle,
          message: store.state == ViewState.error
              ? 'A conexão não respondeu. Tente carregar os dados novamente.'
              : 'Os dados aparecerão aqui assim que os sensores enviarem leituras.',
          action: 'Carregar demonstração',
          onAction: () => store.setState(ViewState.loading));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (store.state == ViewState.offline) ...[
        Surface(
            color: const Color(0xFFF3E8DB),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.wifi_off_rounded, color: N.amber, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                  child: Text('Sem conexão · exibindo as últimas leituras',
                      style: TextStyle(fontSize: 11, color: N.amber))),
              IconButton(
                  onPressed: () => store.setState(ViewState.loading),
                  icon: const Icon(Icons.refresh, size: 19))
            ])),
        const SizedBox(height: 16)
      ],
      child
    ]);
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel(
      {super.key,
      required this.icon,
      required this.title,
      required this.message,
      this.action,
      this.onAction});
  final IconData icon;
  final String title, message;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Surface(
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Column(children: [
            Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: N.canvas),
                child: Icon(icon, size: 30, color: N.wine)),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, color: N.muted, height: 1.5)),
            if (action != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(action!))
            ]
          ])));
}

/// Gráfico vetorial reutilizado a partir do protótipo, com desenho progressivo e seleção.
class NexusChart extends StatefulWidget {
  const NexusChart(
      {super.key,
      required this.values,
      this.dark = false,
      this.unit = '',
      this.labels = const ['−24h', '−16h', '−8h', 'Agora'],
      this.height = 154});
  final List<double> values;
  final bool dark;
  final String unit;
  final List<String> labels;
  final double height;
  @override
  State<NexusChart> createState() => _NexusChartState();
}

class _NexusChartState extends State<NexusChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward();
  int? selected;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
      label:
          'Gráfico com ${widget.values.length} leituras. Último valor ${widget.values.last.toStringAsFixed(1)} ${widget.unit}',
      child: Column(children: [
        GestureDetector(
            onTapDown: (e) => setState(() => selected =
                ((e.localPosition.dx / context.size!.width) *
                        (widget.values.length - 1))
                    .round()
                    .clamp(0, widget.values.length - 1)),
            child: SizedBox(
                height: widget.height,
                width: double.infinity,
                child: Stack(children: [
                  AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) => CustomPaint(
                          size: Size.infinite,
                          painter: _ChartPainter(
                              widget.values,
                              widget.dark,
                              MediaQuery.disableAnimationsOf(context)
                                  ? 1
                                  : controller.value,
                              selected))),
                  if (selected != null)
                    Positioned(
                        top: 2,
                        right: 0,
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                                color: widget.dark ? Colors.white : N.canvas,
                                borderRadius: BorderRadius.circular(12)),
                            child: Text(
                                '${widget.values[selected!].toStringAsFixed(1).replaceAll('.', ',')} ${widget.unit}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    color: N.ink))))
                ]))),
        const SizedBox(height: 10),
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: widget.labels
                .map((label) => Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: widget.dark ? Colors.white60 : N.muted)))
                .toList())
      ]));
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.values, this.dark, this.progress, this.selected);
  final List<double> values;
  final bool dark;
  final double progress;
  final int? selected;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final color = dark ? const Color(0xFFF6DDD0) : N.wine;
    final grid = Paint()
      ..color = (dark ? Colors.white : N.wine).withValues(alpha: 0.10)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final min = values.reduce(math.min) - 0.4,
        max = values.reduce(math.max) + 0.4;
    final points = List.generate(
        values.length,
        (i) => Offset(
            4 + (size.width - 8) * i / (values.length - 1),
            size.height -
                12 -
                (size.height - 24) * (values[i] - min) / (max - min)));
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final mid = (points[i - 1].dx + points[i].dx) / 2;
      path.cubicTo(
          mid, points[i - 1].dy, mid, points[i].dy, points[i].dx, points[i].dy);
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(colors: [
            color.withValues(alpha: 0.17),
            color.withValues(alpha: 0)
          ], begin: Alignment.topCenter, end: Alignment.bottomCenter)
              .createShader(Offset.zero & size));
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round);
    final dot = points[selected ?? points.length - 1];
    canvas.drawCircle(dot, 8, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawCircle(dot, 3.5, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => true;
}

class KeyValue extends StatelessWidget {
  const KeyValue(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(color: N.muted, fontSize: 12))),
        Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))
      ]));
}
