import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'tools_screen.dart';

/// Schermata Impostazioni: profilo, unità, tema/colore, notifiche,
/// blocco PIN/impronta, backup JSON/CSV e accesso a strumenti e badge.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _editProfileDialog(BuildContext context, AppProvider app) async {
    final p = app.profile;
    final nameCtrl = TextEditingController(text: p.name);
    String goal = p.goal;
    String level = p.level;
    int weeklyGoal = p.weeklyGoal;
    int defaultRest = p.defaultRestSeconds;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Modifica profilo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: goal,
                  decoration: const InputDecoration(labelText: 'Obiettivo'),
                  items: const ['Massa', 'Forza', 'Definizione', 'Ricomposizione']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => goal = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: level,
                  decoration: const InputDecoration(labelText: 'Livello'),
                  items: const ['Principiante', 'Intermedio', 'Avanzato']
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => level = v);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Giorni / settimana'),
                    Text('$weeklyGoal',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                Slider(
                  value: weeklyGoal.toDouble(),
                  min: 1,
                  max: 7,
                  divisions: 6,
                  onChanged: (v) =>
                      setModalState(() => weeklyGoal = v.round()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recupero default'),
                    Text(
                      AnalyticsService.formatClock(defaultRest),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Slider(
                  value: defaultRest.toDouble(),
                  min: 30,
                  max: 240,
                  divisions: 14,
                  onChanged: (v) =>
                      setModalState(() => defaultRest = v.round()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await app.updateProfile(p.copyWith(
        name: nameCtrl.text.trim().isEmpty ? p.name : nameCtrl.text.trim(),
        goal: goal,
        level: level,
        weeklyGoal: weeklyGoal,
        defaultRestSeconds: defaultRest,
      ));
    }
    nameCtrl.dispose();
  }

  Future<void> _configurePinDialog(BuildContext context, AppProvider app) async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Imposta PIN (4 cifre)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinCtrl,
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nuovo PIN'),
              ),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Conferma PIN'),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                if (pinCtrl.text.length != 4 ||
                    int.tryParse(pinCtrl.text) == null) {
                  setModalState(() => error = 'Inserisci esattamente 4 cifre.');
                  return;
                }
                if (pinCtrl.text != confirmCtrl.text) {
                  setModalState(() => error = 'I due PIN non coincidono.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Attiva blocco'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await app.updateProfile(app.profile.copyWith(
        lockEnabled: true,
        pinHash: app.hashPin(pinCtrl.text),
      ));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blocco PIN attivato con successo.')),
        );
      }
    }
    pinCtrl.dispose();
    confirmCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final p = app.profile;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          app.activeWorkout != null ? 92 : 28,
        ),
        children: [
          // 1. PROFILO ATLETA
          const SectionHeader(title: 'Profilo'),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.primary.alphaPct(0.16),
                child: Text(
                  p.name.isNotEmpty ? p.name[0].toUpperCase() : 'A',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                  ),
                ),
              ),
              title: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                '${p.goal} • ${p.level} • ${p.weeklyGoal} gg/sett. • Rec. ${AnalyticsService.formatClock(p.defaultRestSeconds)}',
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editProfileDialog(context, app),
            ),
          ),
          const SizedBox(height: 18),

          // 2. STRUMENTI EXTRA, OBIETTIVI E BADGE
          const SectionHeader(title: 'Strumenti & Traguardi'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.flag_rounded),
                  title: const Text('Obiettivi personali'),
                  subtitle: Text('${app.goals.length} obiettivi tracciati'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ToolsScreen(initialTabIndex: 3),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.emoji_events_rounded),
                  title: const Text('Badge e traguardi'),
                  subtitle: const Text('Visualizza medaglie e progressione'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ToolsScreen(initialTabIndex: 4),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calculate_outlined),
                  title: const Text('Calcolatore dischi, 1RM e Tabata'),
                  subtitle: const Text('Bilanciere, percentuali e timer HIIT'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ToolsScreen(initialTabIndex: 0),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. ASPETTO E UNITÀ DI MISURA
          const SectionHeader(title: 'Aspetto e unità'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Unità di peso',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'kg', label: Text('Chilogrammi (kg)')),
                        ButtonSegment(value: 'lb', label: Text('Libbre (lb)')),
                      ],
                      selected: {p.unit},
                      onSelectionChanged: (s) =>
                          app.updateProfile(p.copyWith(unit: s.first)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Tema app',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'light', label: Text('Chiaro')),
                        ButtonSegment(value: 'dark', label: Text('Scuro')),
                        ButtonSegment(value: 'system', label: Text('Auto')),
                      ],
                      selected: {p.themeMode},
                      onSelectionChanged: (s) =>
                          app.updateProfile(p.copyWith(themeMode: s.first)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Colore principale',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: AppTheme.accentOptions.map((opt) {
                      final selected = p.accentColor == opt.id;
                      return GestureDetector(
                        onTap: () => app.updateProfile(
                          p.copyWith(accentColor: opt.id),
                        ),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: opt.color,
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(
                                    color: cs.onSurface,
                                    width: 3,
                                  )
                                : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 4. NOTIFICHE PROMEMORIA
          const SectionHeader(title: 'Notifiche'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Promemoria giorni allenamento'),
                  subtitle: const Text(
                    'Sincronizzati automaticamente con i giorni delle schede',
                  ),
                  value: p.notificationsEnabled,
                  onChanged: (enabled) async {
                    if (enabled) {
                      await NotificationService.instance.requestPermission();
                    }
                    await app.updateProfile(
                      p.copyWith(notificationsEnabled: enabled),
                    );
                  },
                ),
                if (p.notificationsEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.access_time_rounded),
                    title: const Text('Orario notifica'),
                    trailing: Text(
                      '${p.reminderHour.toString().padLeft(2, '0')}:${p.reminderMinute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                      ),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: p.reminderHour,
                          minute: p.reminderMinute,
                        ),
                      );
                      if (picked != null) {
                        await app.updateProfile(p.copyWith(
                          reminderHour: picked.hour,
                          reminderMinute: picked.minute,
                        ));
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 5. SICUREZZA (PIN / IMPRONTA)
          const SectionHeader(title: 'Privacy e sicurezza'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline_rounded),
                  title: const Text('Blocco accesso app'),
                  subtitle: Text(
                    p.lockEnabled
                        ? 'Attivo all\'apertura dell\'app'
                        : 'Disattivato',
                  ),
                  value: p.lockEnabled,
                  onChanged: (val) async {
                    if (val) {
                      if (p.pinHash == null) {
                        await _configurePinDialog(context, app);
                      } else {
                        await app.updateProfile(p.copyWith(lockEnabled: true));
                      }
                    } else {
                      await app.updateProfile(
                        p.copyWith(lockEnabled: false, biometricEnabled: false),
                      );
                    }
                  },
                ),
                if (p.lockEnabled) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint_rounded),
                    title: const Text('Sblocco con impronta / volto'),
                    value: p.biometricEnabled,
                    onChanged: (val) =>
                        app.updateProfile(p.copyWith(biometricEnabled: val)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.pin_outlined),
                    title: const Text('Cambia PIN a 4 cifre'),
                    onTap: () => _configurePinDialog(context, app),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.phonelink_lock_rounded),
                    title: const Text('Blocca app adesso'),
                    onTap: app.lockApp,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 6. BACKUP & ESPORTAZIONE DATI (JSON / CSV)
          const SectionHeader(title: 'Backup e dati (100% offline)'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Esporta backup completo (JSON)'),
                  subtitle: const Text(
                    'Salva o condividi tutto il database (schede, storico, misure, obiettivi)',
                  ),
                  onTap: () async {
                    try {
                      await app.exportAndShareJsonBackup();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Errore export JSON: $e')),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: const Text('Importa backup (JSON)'),
                  subtitle: const Text(
                    'Ripristina un file di backup IronTrack salvato in precedenza',
                  ),
                  onTap: () async {
                    try {
                      final imported = await app.importJsonBackupFromFile();
                      if (imported && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Backup ripristinato con successo!'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Errore importazione: $e')),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.table_view_outlined),
                  title: const Text('Esporta allenamenti (CSV / Excel)'),
                  subtitle: const Text(
                    'Genera un foglio CSV con tutte le serie completate',
                  ),
                  onTap: () async {
                    try {
                      await app.exportAndShareCsv();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Errore export CSV: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}