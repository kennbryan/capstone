import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/config/app_config.dart';
import 'package:msu_wellbeing/core/network/api_exception.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/utils/link_launcher.dart';
import 'package:msu_wellbeing/core/widgets/error_message.dart';
import 'package:msu_wellbeing/core/widgets/help_button.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/illustration.dart';
import 'package:msu_wellbeing/core/widgets/msu_logo.dart';
import 'package:msu_wellbeing/core/widgets/primary_button.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/auth_controller.dart';
import 'package:msu_wellbeing/features/auth/presentation/widgets/demo_accounts_sheet.dart';
import 'package:msu_wellbeing/features/remote_config/presentation/controllers/remote_config_controller.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Email + password sign-in with the assessment website account.
class LoginScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await ref
        .read(authControllerProvider.notifier)
        .login(email: _email.text, password: _password.text);
    if (!mounted) return;
    final l10n = context.l10n;
    setState(() {
      _busy = false;
      _error = switch (failure?.kind) {
        null => null,
        ApiExceptionKind.unauthorized => l10n.loginInvalid,
        _ => l10n.describeError(failure),
      };
    });
  }

  Future<void> _openWebsite(String url) async {
    final opened = await ref.read(linkLauncherProvider).open(Uri.parse(url));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.linkOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final websiteUrl = ref.watch(
      remoteConfigProvider.select(
        (config) => config.value?.assessmentWebsiteUrl,
      ),
    );

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _LoginHeader(),
            Transform.translate(
              offset: const Offset(0, -AppSpacing.xxl),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSizes.maxContentWidth,
                  ),
                  child: Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: _form(l10n, theme),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextButton(
                        onPressed: websiteUrl == null || websiteUrl.isEmpty
                            ? null
                            : () => _openWebsite(websiteUrl),
                        child: Text(
                          l10n.loginRegister,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (AppConfig.demoLoginEnabled)
                        DemoAccountsButton(
                          onPick: (account) => setState(() {
                            _email.text = account.email;
                            _password.text = account.password;
                            _error = null;
                          }),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(AppLocalizations l10n, ThemeData theme) {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.loginEmail,
                prefixIcon: const Icon(Icons.mail_outline),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? l10n.loginEmailRequired : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _password,
              enabled: !_busy,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.loginPassword,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscure
                      ? l10n.loginShowPassword
                      : l10n.loginHidePassword,
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (value) =>
                  (value ?? '').isEmpty ? l10n.loginPasswordRequired : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: l10n.loginSubmit,
              busy: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Solid brand header with the MSU logo, a small plant drawing, and the
/// help button.
class _LoginHeader extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final onBrand = context.gradients.onBrand;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: context.gradients.brand,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.hero),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.sm,
            AppSpacing.xxl * 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Align(
                alignment: AlignmentDirectional.centerEnd,
                child: HelpButton(onBrand: true),
              ),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MsuLogo(size: AppSizes.avatarLg, onBrand: true),
                  Spacer(),
                  Illustration(
                    IllustrationKind.growth,
                    height: AppSizes.illustrationHeader,
                    onBrand: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.loginTitle,
                style: theme.textTheme.headlineMedium?.copyWith(color: onBrand),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.loginSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onBrand.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
