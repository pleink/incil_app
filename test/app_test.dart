import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:incil_camp_app/cubits/app_shell/app_shell_cubit.dart';
import 'package:incil_camp_app/cubits/app_shell/app_shell_state.dart';
import 'package:incil_camp_app/navigation/app_router.dart';
import 'package:incil_camp_app/style/incil_system_ui.dart';

class _AppShellCubitMock extends MockCubit<AppShellState>
    implements AppShellCubit {}

void main() {
  // Mirrors IncilApp: an annotation above MaterialApp must drive the status
  // bar and follow the shell state.
  testWidgets('status-bar style is applied above the router and tracks state', (
    tester,
  ) async {
    final states = StreamController<AppShellState>();
    addTearDown(states.close);
    final cubit = _AppShellCubitMock();
    whenListen(cubit, states.stream, initialState: const AppShellSplash());

    await tester.pumpWidget(
      BlocProvider<AppShellCubit>.value(
        value: cubit,
        child: BlocBuilder<AppShellCubit, AppShellState>(
          builder: (_, state) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlayStyleFor(state),
            child: const MaterialApp(home: Scaffold()),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(SystemChrome.latestStyle, IncilSystemUi.lightIcons);

    states.add(
      const AppShellWebView(
        url: 'https://x',
        allowedHosts: [],
        inAppBrowserHosts: [],
        externalBrowserUrls: [],
        oneSignalTags: {},
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(SystemChrome.latestStyle, IncilSystemUi.darkIcons);
  });
}
