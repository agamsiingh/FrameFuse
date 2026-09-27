import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../projects/domain/project.dart';
import '../../projects/presentation/library_controller.dart';
import '../../projects/presentation/project_sheet.dart';
import '../../recording/presentation/widgets/trim_bar.dart';

/// Library: projects and their takes.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  String? _projectId;
  bool _favoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final projects = library.data.projects;
    final projectId = _projectId ?? library.currentProject?.id;
    final project = projects.where((p) => p.id == projectId).firstOrNull ??
        library.currentProject;
    var takes = project == null ? const <Take>[] : library.data.takesFor(project.id);
    if (_favoritesOnly) takes = takes.where((t) => t.favorite).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            tooltip: 'Favourites only',
            onPressed: () => setState(() => _favoritesOnly = !_favoritesOnly),
            icon: Icon(
              Icons.star_rounded,
              color: _favoritesOnly ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
          IconButton(
            tooltip: 'New project',
            onPressed: () async {
              final name = await promptText(context, title: 'New project', confirm: 'Create');
              if (name == null) return;
              final p = await ref.read(libraryProvider.notifier).createProject(name);
              setState(() => _projectId = p.id);
            },
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
      body: !library.isLoaded
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Column(
              children: [
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: projects.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final p = projects[i];
                      final selected = p.id == project?.id;
                      return GestureDetector(
                        onTap: () => setState(() => _projectId = p.id),
                        onLongPress: () => _projectMenu(p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF1D9CAB) : AppColors.control,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            '${p.name}  ${library.data.takesFor(p.id).length}',
                            style: TextStyle(
                              color: selected ? const Color(0xFF002230) : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: takes.isEmpty
                      ? _empty()
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 10,
                            childAspectRatio: 9 / 19.5,
                          ),
                          itemCount: takes.length,
                          itemBuilder: (context, i) => _TakeTile(
                            take: takes[i],
                            onTap: () => Navigator.of(context).pushNamed('/review', arguments: takes[i].id),
                            onLongPress: () => _takeMenu(takes[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.video_library_outlined, color: AppColors.textTertiary, size: 48),
          const SizedBox(height: 14),
          Text(
            _favoritesOnly ? 'No favourite takes yet' : 'No takes yet',
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Record once — get 9:16 and 16:9.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
        ],
      ),
    );
  }

  Future<void> _projectMenu(Project p) async {
    final notifier = ref.read(libraryProvider.notifier);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Record into this project'),
              onTap: () => Navigator.pop(ctx, 'select'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.record),
              title: const Text('Delete project', style: TextStyle(color: AppColors.record)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'select':
        await notifier.selectProject(p.id);
      case 'rename':
        final name = await promptText(context, title: 'Rename project', initial: p.name);
        if (name != null) await notifier.renameProject(p.id, name);
      case 'delete':
        final ok = await _confirm(
          'Delete "${p.name}"?',
          'All of its takes will be removed from FrameFuse. Copies saved to your gallery are kept.',
        );
        if (ok) {
          await notifier.deleteProject(p.id);
          setState(() => _projectId = null);
        }
    }
  }

  Future<void> _takeMenu(Take take) async {
    final ok = await _confirm(
      'Delete ${take.label}?',
      'Copies saved to your gallery are kept.',
    );
    if (ok) await ref.read(libraryProvider.notifier).deleteTake(take.id);
  }

  Future<bool> _confirm(String title, String body) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 18)),
        content: Text(body, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.record)),
          ),
        ],
      ),
    );
    return result == true;
  }
}

class _TakeTile extends StatelessWidget {
  final Take take;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TakeTile({required this.take, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final thumb = take.isVideo ? take.thumbnailPath : take.portraitPath;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: AppColors.card),
                  Image.file(
                    File(thumb),
                    fit: BoxFit.cover,
                    cacheWidth: 270,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(Icons.movie_outlined, color: AppColors.textTertiary),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: _Badge(
                      text: take.isVideo ? formatClock(take.trimmedDuration) : 'Photo',
                    ),
                  ),
                  if (take.favorite)
                    const Positioned(
                      right: 5,
                      top: 5,
                      child: Icon(Icons.star_rounded, color: AppColors.accent, size: 18),
                    ),
                  if (take.isExported)
                    const Positioned(
                      right: 6,
                      bottom: 6,
                      child: Icon(Icons.check_circle, color: AppColors.accent, size: 16),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            take.label,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Text(
            take.scene,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}
