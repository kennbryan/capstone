import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:msu_wellbeing/core/router/app_routes.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/app_card.dart';
import 'package:msu_wellbeing/core/widgets/section_header.dart';
import 'package:msu_wellbeing/core/widgets/tab_scaffold.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/auth_controller.dart';
import 'package:msu_wellbeing/features/profile/presentation/controllers/settings_controllers.dart';
import 'package:msu_wellbeing/features/profile/presentation/widgets/profile_widgets.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Profil: name, privacy, consent history, app lock, theme, help, about,
/// and logout.
class ProfileScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _toggleLock(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) async {
    final l10n = context.l10n;
    final result = await ref
        .read(appLockControllerProvider.notifier)
        .setEnabled(enabled: enabled, reason: l10n.lockReason);
    if (!context.mounted || result == AppLockChange.changed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == AppLockChange.unsupported
              ? l10n.profileAppLockUnsupported
              : l10n.profileAppLockFailed,
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.logoutConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lock = ref.watch(appLockControllerProvider).value;
    final supported = ref.watch(appLockSupportedProvider).value ?? true;
    final themeMode = ref.watch(themeModeControllerProvider);

    Widget tile({
      required IconData icon,
      required String title,
      String? subtitle,
      VoidCallback? onTap,
    }) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );

    return TabScaffold(
      title: l10n.navProfile,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.sm,
          AppSpacing.screen,
          AppSpacing.xxl,
        ),
        children: [
          const ProfileHeader(),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: l10n.profileSectionAccount),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                tile(
                  icon: Icons.privacy_tip_outlined,
                  title: l10n.profilePrivacy,
                  subtitle: l10n.profilePrivacySubtitle,
                  onTap: () => context.push(AppRoutes.privacy),
                ),
                tile(
                  icon: Icons.history,
                  title: l10n.profileConsentHistory,
                  onTap: () => context.push(AppRoutes.consentHistory),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline),
                  title: Text(l10n.profileAppLock),
                  subtitle: Text(
                    supported
                        ? l10n.profileAppLockSubtitle
                        : l10n.profileAppLockUnsupported,
                  ),
                  value: lock?.enabled ?? false,
                  onChanged: !supported || lock == null
                      ? null
                      : (value) => _toggleLock(context, ref, enabled: value),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: l10n.profileSectionApp),
          Text(
            l10n.profileTheme,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.themeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.themeLight),
              ),
              ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeDark)),
            ],
            selected: {themeMode},
            onSelectionChanged: (selection) => ref
                .read(themeModeControllerProvider.notifier)
                .select(selection.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                tile(
                  icon: Icons.support_outlined,
                  title: l10n.profileEmergency,
                  onTap: () => context.push(AppRoutes.crisis),
                ),
                tile(
                  icon: Icons.info_outline,
                  title: l10n.profileAbout,
                  onTap: () => showAboutSheet(context),
                ),
                tile(
                  icon: Icons.logout,
                  title: l10n.profileLogout,
                  onTap: () => _logout(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
