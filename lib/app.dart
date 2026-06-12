import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'config/flavor.dart';
import 'cubits/app_shell/app_shell_cubit.dart';
import 'di/service_locator.dart';
import 'l10n/app_localizations.dart';
import 'navigation/app_router.dart';
import 'services/app_state_service.dart';
import 'services/local_storage_service.dart';
import 'services/push_service.dart';
import 'services/version_service.dart';
import 'style/incil_theme.dart';

class IncilApp extends StatefulWidget {
  const IncilApp({super.key, required this.flavor});

  final Flavor flavor;

  @override
  State<IncilApp> createState() => _IncilAppState();
}

class _IncilAppState extends State<IncilApp> {
  late final AppShellCubit _cubit = AppShellCubit(
    appStateService: getIt<AppStateService>(),
    versionService: getIt<VersionService>(),
    storage: getIt<LocalStorageService>(),
    pushService: getIt<PushService>(),
  );

  late final _router = buildAppRouter(_cubit);

  @override
  void initState() {
    super.initState();
    // Route OneSignal notification taps through the shell so the host allowlist
    // applies and a tap can never bypass an emergency / force-update screen.
    getIt<PushService>().onTargetUrl = _cubit.handleDeepLink;
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AppShellCubit>.value(
      value: _cubit,
      child: MaterialApp.router(
        title: widget.flavor.displayName,
        debugShowCheckedModeBanner: widget.flavor == Flavor.dev,
        theme: IncilTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: _router,
      ),
    );
  }
}
