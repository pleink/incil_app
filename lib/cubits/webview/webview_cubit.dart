import 'package:flutter_bloc/flutter_bloc.dart';

import 'webview_state.dart';

class WebViewCubit extends Cubit<WebViewState> {
  WebViewCubit() : super(const WebViewLoading());

  void onPageStarted() => emit(const WebViewLoading());
  void onPageFinished() => emit(const WebViewReady());
  void onLoadFailed(String description) => emit(WebViewFailed(description));
}
