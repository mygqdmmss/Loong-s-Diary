import 'package:moodiary/src/rust/frb_generated.dart';

/// Shares the full FRB initialization, including the Rust-side initializers.
class RustUtil {
  RustUtil._();

  static final _initializer = RustInitializer(RustLib.init);

  static Future<void> ensureInitialized() => _initializer.ensureInitialized();
}

class RustInitializer {
  RustInitializer(this._initialize);

  final Future<void> Function() _initialize;
  Future<void>? _initialization;

  // FRB may already have set up its API when an initializer fails. Retain the
  // failed future too: trying init again can leave FRB initialized twice.
  Future<void> ensureInitialized() =>
      _initialization ??= Future<void>.sync(_initialize);
}
