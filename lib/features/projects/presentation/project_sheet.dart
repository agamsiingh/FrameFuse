import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import 'library_controller.dart';

/// Pick / create / rename the project and set the scene name that new takes
/// are filed under ("My Project / Untitled").
Future<void> showProjectSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.card,
    builder: (_) => const _ProjectSheet(),
  );
}

/// Simple single-field text prompt.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String confirm = 'Save',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 18)),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        cursorColor: AppColors.accent,
        decoration: const InputDecoration(
          counterText: '',
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.accent),
          ),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(confirm),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

class _ProjectSheet extends ConsumerWidget {
  const _ProjectSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final notifier = ref.read(libraryProvider.notifier);
    final current = library.currentProject;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filing new takes under',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                library.currentLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _SheetTile(
                icon: Icons.movie_filter_outlined,
                title: 'Scene',
                trailing: library.currentScene,
                onTap: () async {
                  final scene = await promptText(
                    context,
                    title: 'Scene name',
                    initial: library.currentScene,
                  );
                  if (scene != null) await notifier.setScene(scene);
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'PROJECTS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final project in library.data.projects)
                      _SheetTile(
                        icon: project.id == current?.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        iconColor: project.id == current?.id
                            ? AppColors.accent
                            : AppColors.textSecondary,
                        title: project.name,
                        trailing:
                            '${library.data.takesFor(project.id).length} takes',
                        onTap: () => notifier.selectProject(project.id),
                        onLongPress: () async {
                          final name = await promptText(
                            context,
                            title: 'Rename project',
                            initial: project.name,
                          );
                          if (name != null) {
                            await notifier.renameProject(project.id, name);
                          }
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _SheetTile(
                icon: Icons.add,
                iconColor: AppColors.accent,
                title: 'New project',
                onTap: () async {
                  final name = await promptText(
                    context,
                    title: 'New project',
                    confirm: 'Create',
                  );
                  if (name != null) await notifier.createProject(name);
                },
              ),
              const SizedBox(height: 6),
              const Text(
                'Long-press a project to rename it.',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? trailing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SheetTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor = Colors.white,
    this.trailing,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.control,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          height: 48,
          margin: const EdgeInsets.only(bottom: 0),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ),
    ).withBottomGap();
  }
}

extension on Widget {
  Widget withBottomGap() =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: this);
}
