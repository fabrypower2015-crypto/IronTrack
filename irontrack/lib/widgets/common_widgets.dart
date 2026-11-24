import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// Restituisce un colore distintivo per ogni gruppo muscolare.
Color muscleGroupColor(String group) {
  switch (group) {
    case MuscleGroups.petto:
      return const Color(0xFFEF4444);
    case MuscleGroups.schiena:
      return const Color(0xFF3B82F6);
    case MuscleGroups.spalle:
      return const Color(0xFFF59E0B);
    case MuscleGroups.bicipiti:
      return const Color(0xFF8B5CF6);
    case MuscleGroups.tricipiti:
      return const Color(0xFFEC4899);
    case MuscleGroups.gambe:
      return const Color(0xFF10B981);
    case MuscleGroups.glutei:
      return const Color(0xFF14B8A6);
    case MuscleGroups.addome:
      return const Color(0xFFF97316);
    case MuscleGroups.cardio:
      return const Color(0xFF06B6D4);
    default:
      return const Color(0xFF64748B);
  }
}

/// Restituisce l'icona associata a ciascun gruppo muscolare.
IconData muscleGroupIcon(String group) {
  switch (group) {
    case MuscleGroups.petto:
      return Icons.fitness_center;
    case MuscleGroups.schiena:
      return Icons.accessibility_new;
    case MuscleGroups.spalle:
      return Icons.expand;
    case MuscleGroups.bicipiti:
      return Icons.sports_martial_arts;
    case MuscleGroups.tricipiti:
      return Icons.bolt;
    case MuscleGroups.gambe:
      return Icons.directions_walk;
    case MuscleGroups.glutei:
      return Icons.airline_seat_legroom_extra;
    case MuscleGroups.addome:
      return Icons.grid_view_rounded;
    case MuscleGroups.cardio:
      return Icons.directions_run;
    default:
      return Icons.fitness_center;
  }
}

/// Associa il codice icona di un AchievementBadge alla relativa IconData.
IconData badgeIconData(String iconName) {
  switch (iconName) {
    case 'flag':
      return Icons.flag_rounded;
    case 'fitness':
      return Icons.fitness_center_rounded;
    case 'military':
      return Icons.military_tech_rounded;
    case 'trophy':
      return Icons.emoji_events_rounded;
    case 'fire':
      return Icons.local_fire_department_rounded;
    case 'bolt':
      return Icons.bolt_rounded;
    case 'star':
      return Icons.star_rounded;
    case 'workspace':
      return Icons.workspace_premium_rounded;
    case 'weight':
      return Icons.monitor_weight_rounded;
    case 'diamond':
      return Icons.diamond_rounded;
    case 'scale':
      return Icons.scale_rounded;
    case 'camera':
      return Icons.photo_camera_rounded;
    default:
      return Icons.emoji_events_rounded;
  }
}

/// Formatta una data in italiano compatto (es. "24 nov 2026").
String formatItalianDate(DateTime date) {
  return DateFormat('d MMM yyyy', 'it_IT').format(date);
}

/// Formatta giorno e mese (es. "24 nov").
String formatShortDate(DateTime date) {
  return DateFormat('d MMM', 'it_IT').format(date);
}

/// Formatta data e ora (es. "24 nov • 18:30").
String formatItalianDateTime(DateTime date) {
  return DateFormat('d MMM • HH:mm', 'it_IT').format(date);
}

/// Intestazione di sezione con titolo e azione opzionale a destra.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Pillola colorata per mostrare variazioni percentuali (+verde / -rosso).
class DeltaBadge extends StatelessWidget {
  final double? percent;
  final bool invertColors;

  const DeltaBadge({
    super.key,
    required this.percent,
    this.invertColors = false,
  });

  @override
  Widget build(BuildContext context) {
    if (percent == null) {
      return const Text(
        '—',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    final value = percent!;
    final isPositive = value >= 0;
    final good = invertColors ? !isPositive : isPositive;
    final color = value.abs() < 0.05
        ? Colors.grey
        : (good ? const Color(0xFF10B981) : const Color(0xFFEF4444));
    final sign = value > 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.alphaPct(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            value.abs() < 0.05
                ? Icons.remove
                : (isPositive ? Icons.trending_up : Icons.trending_down),
            size: 13,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '$sign${value.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card compatta per mostrare un indicatore chiave (KPI).
class KpiCard extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String value;
  final String? subtitle;
  final double? deltaPercent;

  const KpiCard({
    super.key,
    required this.icon,
    this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
    this.deltaPercent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = iconColor ?? cs.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accent.alphaPct(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const Spacer(),
                if (deltaPercent != null) DeltaBadge(percent: deltaPercent),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.alphaPct(0.8),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Stato vuoto elegante quando non esistono ancora dati in una sezione.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.primary.alphaPct(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: cs.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            if (buttonLabel != null && onPressed != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onPressed,
                child: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet riutilizzabile per cercare e selezionare un esercizio dalla libreria.
class ExercisePickerSheet extends StatefulWidget {
  final List<Exercise> exercises;
  final String title;

  const ExercisePickerSheet({
    super.key,
    required this.exercises,
    this.title = 'Seleziona esercizio',
  });

  static Future<Exercise?> show(
    BuildContext context, {
    required List<Exercise> exercises,
    String title = 'Seleziona esercizio',
  }) {
    return showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: ExercisePickerSheet(exercises: exercises, title: title),
      ),
    );
  }

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  String _search = '';
  String _selectedMuscle = 'Tutti';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = widget.exercises.where((e) {
      final matchesGroup =
          _selectedMuscle == 'Tutti' || e.muscleGroup == _selectedMuscle;
      final matchesText = _search.trim().isEmpty ||
          e.name.toLowerCase().contains(_search.toLowerCase()) ||
          e.equipment.toLowerCase().contains(_search.toLowerCase());
      return matchesGroup && matchesText;
    }).toList();

    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: cs.outlineVariant,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              hintText: 'Cerca per nome o attrezzo...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: ['Tutti', ...MuscleGroups.all].map((group) {
              final selected = _selectedMuscle == group;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(group),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedMuscle = group),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyStateView(
                  icon: Icons.search_off_rounded,
                  title: 'Nessun esercizio trovato',
                  subtitle: 'Prova a cambiare il testo o il gruppo muscolare.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final ex = filtered[index];
                    final color = muscleGroupColor(ex.muscleGroup);
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.alphaPct(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            muscleGroupIcon(ex.muscleGroup),
                            color: color,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          ex.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('${ex.muscleGroup} • ${ex.equipment}'),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () => Navigator.pop(context, ex),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}