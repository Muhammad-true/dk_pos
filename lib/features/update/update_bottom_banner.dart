import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/features/admin/data/app_versions_repository.dart';
import 'package:dk_pos/features/update/update_coordinator.dart';

/// Подключает [UpdateCoordinator] к HTTP и репозиторию версий после старта приложения.
class UpdateCoordinatorHost extends StatefulWidget {
  const UpdateCoordinatorHost({
    super.key,
    required this.coordinator,
    required this.child,
  });

  final UpdateCoordinator coordinator;
  final Widget child;

  @override
  State<UpdateCoordinatorHost> createState() => _UpdateCoordinatorHostState();
}

class _UpdateCoordinatorHostState extends State<UpdateCoordinatorHost> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.coordinator.bind(
      http: context.read<HttpClient>(),
      versionsRepo: context.read<AppVersionsRepository>(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Нижняя панель: «Доступно обновление …» + кнопка «Установить».
class UpdateBottomBanner extends StatelessWidget {
  const UpdateBottomBanner({
    super.key,
    required this.coordinator,
    required this.child,
  });

  final UpdateCoordinator coordinator;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: coordinator,
      builder: (context, child) {
        final update = coordinator.currentReady;
        return Stack(
          fit: StackFit.expand,
          children: [
            child!,
            if (update != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: Material(
                    elevation: 8,
                    shadowColor: Colors.black26,
                    color: Theme.of(context).colorScheme.inverseSurface,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.system_update_alt_rounded,
                            color: Theme.of(context).colorScheme.onInverseSurface,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Доступно обновление ${update.displayName} '
                              '(${update.targetVersion})',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onInverseSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (coordinator.isInstalling)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else
                            FilledButton(
                              onPressed: () async {
                                final result =
                                    await coordinator.installCurrent();
                                if (!context.mounted || result == null) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(result.message)),
                                );
                              },
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('Установить'),
                            ),
                          IconButton(
                            tooltip: 'Позже (до следующего запуска)',
                            onPressed: coordinator.canDismissCurrent
                                ? coordinator.dismissCurrent
                                : null,
                            icon: Icon(
                              Icons.close_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onInverseSurface
                                  .withValues(
                                    alpha: coordinator.canDismissCurrent
                                        ? 1
                                        : 0.35,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: child,
    );
  }
}
