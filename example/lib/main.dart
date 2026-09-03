import 'package:device_integrity_check/device_integrity_check.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Device integrity',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F5F8B)),
          useMaterial3: true,
        ),
        home: const IntegrityPage(),
      );
}

class IntegrityPage extends StatefulWidget {
  const IntegrityPage({super.key});

  @override
  State<IntegrityPage> createState() => _IntegrityPageState();
}

class _IntegrityPageState extends State<IntegrityPage> {
  // Probing costs real work on the platform thread — a full root scan was
  // measured at 1.8 seconds on a cold start. Hold one future and resolve it
  // once, rather than calling the getters from build(): a FutureBuilder whose
  // `future` is created inline re-runs the whole scan on every rebuild, which
  // is what the previous version of this example demonstrated by accident.
  late Future<IntegrityReport> _report;

  @override
  void initState() {
    super.initState();
    _report = _evaluate();
  }

  Future<IntegrityReport> _evaluate() => DeviceIntegrity(
        onError: (signal, error, stackTrace) {
          debugPrint(
            'probe ${signal?.name ?? 'platformVersion'} failed: $error',
          );
        },
      ).evaluate();

  void _refresh() {
    // Start the work first, then assign inside setState. An arrow body here
    // would return the assignment's value — a Future — which setState rejects.
    final next = _evaluate();
    setState(() {
      _report = next;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Device integrity'),
          actions: [
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Re-run checks',
            ),
          ],
        ),
        body: FutureBuilder<IntegrityReport>(
          future: _report,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _Message(
                icon: Icons.error_outline,
                text: 'evaluate() threw, which it should never do:\n'
                    '${snapshot.error}',
              );
            }
            return _ReportView(report: snapshot.data!);
          },
        ),
      );
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report});

  final IntegrityReport report;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            report.platformVersion ?? 'platform version unavailable',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            report.isComplete
                ? 'All checks ran.'
                : 'Some checks could not run — the booleans below are a '
                    'partial answer.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          for (final signal in IntegritySignal.values)
            _SignalTile(
              signal: signal,
              detected: report.detected.contains(signal),
              unavailable: report.unavailable.contains(signal),
            ),
        ],
      );
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({
    required this.signal,
    required this.detected,
    required this.unavailable,
  });

  final IntegritySignal signal;
  final bool detected;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Three outcomes, not two: "could not be checked" is deliberately distinct
    // from "not detected", because an unprobed signal says nothing about the
    // device and must not read as a clean result.
    final IconData icon;
    final Color color;
    final String label;
    if (unavailable) {
      icon = Icons.help_outline;
      color = scheme.outline;
      label = 'could not be checked';
    } else if (detected) {
      icon = Icons.warning_amber_rounded;
      color = scheme.error;
      label = 'detected';
    } else {
      icon = Icons.check_circle_outline;
      color = scheme.primary;
      label = 'not detected';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(signal.name),
        subtitle: Text(label),
        trailing: Text(
          signal.methodName,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
