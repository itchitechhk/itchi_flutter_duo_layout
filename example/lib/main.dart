import 'dart:async';

import 'package:flutter/material.dart';
import 'package:itchi_flutter_duo_layout/itchi_flutter_duo_layout.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<DuoFoldSnapshot>? _foldSub;
  StreamSubscription<String>? _railSub;

  DuoFoldSnapshot? _fold;
  ItchiRailStatus? _railStatus;
  String _lastTap = '—';

  @override
  void initState() {
    super.initState();
    _foldSub = ItchiDuoFold.snapshots.listen((snap) {
      if (!mounted) return;
      setState(() => _fold = snap);
    });
    _railSub = ItchiDuoRail.onItemTap.listen((id) {
      if (!mounted) return;
      setState(() => _lastTap = id);
      if (id == ItchiRailItem.backId) {
        _navigatorKey.currentState?.maybePop();
      }
    });
    unawaited(_showBack());
  }

  Future<void> _showBack() async {
    final status = await ItchiDuoRail.setItems([ItchiRailItem.back()]);
    if (!mounted) return;
    setState(() => _railStatus = status);
  }

  Future<void> _clearRail() async {
    final status = await ItchiDuoRail.setItems(const []);
    if (!mounted) return;
    setState(() => _railStatus = status);
  }

  @override
  void dispose() {
    unawaited(ItchiDuoRail.setItems(const []));
    _foldSub?.cancel();
    _railSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fold = _fold;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      home: Scaffold(
        appBar: AppBar(title: const Text('itchi_flutter_duo_layout')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Rail status: ${_railStatus?.name ?? '…'}'),
            Text('Last rail tap: $_lastTap'),
            const SizedBox(height: 16),
            Text(
              fold == null
                  ? 'Fold: waiting…'
                  : 'Fold: ${fold.availability.name}'
                      '${fold.pose != null ? ' / ${fold.pose!.name}' : ''}',
            ),
            if (fold?.angleDegrees != null)
              Text('Hinge angle: ${fold!.angleDegrees!.toStringAsFixed(1)}°'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _showBack,
              child: const Text('Show side Back'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _clearRail,
              child: const Text('Clear side rail'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                _navigatorKey.currentState?.push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Detail')),
                      body: const Center(
                        child: Text('Tap native side Back to pop'),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Push a route'),
            ),
          ],
        ),
      ),
    );
  }
}
