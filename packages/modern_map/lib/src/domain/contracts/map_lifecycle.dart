import 'package:flutter/widgets.dart';

abstract interface class ModernMapLifecycleListener {
  void onInit();
  void onDispose();
  void onAppLifecycleStateChanged(AppLifecycleState state);
}

class ModernMapLifecycleListenerAdapter implements ModernMapLifecycleListener {
  const ModernMapLifecycleListenerAdapter({
    this.onInitCallback,
    this.onDisposeCallback,
    this.onAppLifecycleStateChangedCallback,
  });

  final void Function()? onInitCallback;
  final void Function()? onDisposeCallback;
  final void Function(AppLifecycleState state)? onAppLifecycleStateChangedCallback;

  @override
  void onInit() => onInitCallback?.call();

  @override
  void onDispose() => onDisposeCallback?.call();

  @override
  void onAppLifecycleStateChanged(AppLifecycleState state) {
    onAppLifecycleStateChangedCallback?.call(state);
  }
}

