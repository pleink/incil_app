import 'package:equatable/equatable.dart';

sealed class WebViewState extends Equatable {
  const WebViewState();

  @override
  List<Object?> get props => const [];
}

final class WebViewLoading extends WebViewState {
  const WebViewLoading();
}

final class WebViewReady extends WebViewState {
  const WebViewReady();
}

final class WebViewFailed extends WebViewState {
  const WebViewFailed(this.description);
  final String description;

  @override
  List<Object?> get props => [description];
}
