import 'package:flutter/material.dart';

class DataPage extends StatefulWidget {
  const DataPage({super.key, required this.title, required this.future, required this.builder});

  final String title;
  final Future<Object?> Function() future;
  final Widget Function(BuildContext, Object?) builder;

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  late Future<Object?> _pending;

  @override
  void initState() {
    super.initState();
    _pending = widget.future();
  }

  @override
  void didUpdateWidget(covariant DataPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.future != widget.future) _pending = widget.future();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Object?>(
      future: _pending,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Falha ao consultar ${widget.title} via sessão autenticada.'),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(() => _pending = widget.future()),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        }
        return widget.builder(context, snapshot.data);
      },
    );
  }
}
