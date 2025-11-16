import 'app_exceptions.dart';

/// Represents the state of an asynchronous operation
enum LoadingState { initial, loading, loaded, error, empty }

/// A generic class that handles loading state with data
class DataState<T> {
  final LoadingState state;
  final T? data;
  final AppException? error;
  final String? loadingMessage;

  const DataState._({
    required this.state,
    this.data,
    this.error,
    this.loadingMessage,
  });

  /// Initial state
  const DataState.initial() : this._(state: LoadingState.initial);

  /// Loading state with optional message
  const DataState.loading({String? message})
    : this._(
        state: LoadingState.loading,
        loadingMessage: message ?? 'Loading...',
      );

  /// Success state with data
  const DataState.loaded(T data)
    : this._(state: LoadingState.loaded, data: data);

  /// Error state with exception
  const DataState.error(AppException error)
    : this._(state: LoadingState.error, error: error);

  /// Empty state (e.g., no results)
  const DataState.empty() : this._(state: LoadingState.empty);

  /// Whether the state is initial
  bool get isInitial => state == LoadingState.initial;

  /// Whether the state is loading
  bool get isLoading => state == LoadingState.loading;

  /// Whether the state is loaded
  bool get isLoaded => state == LoadingState.loaded;

  /// Whether the state is error
  bool get isError => state == LoadingState.error;

  /// Whether the state is empty
  bool get isEmpty => state == LoadingState.empty;

  /// Maps the data to a new DataState with transformed data
  DataState<R> map<R>(R Function(T) transform) {
    if (state != LoadingState.loaded || data == null) {
      return DataState<R>._(
        state: state,
        error: error,
        loadingMessage: loadingMessage,
      );
    }
    return DataState<R>.loaded(transform(data as T));
  }

  /// Handles the state with callbacks and returns a value of type R
  R when<R>({
    required R Function() initial,
    required R Function(String? message) loading,
    required R Function(T data) loaded,
    required R Function(AppException error) error,
    required R Function() empty,
  }) {
    switch (state) {
      case LoadingState.initial:
        return initial();
      case LoadingState.loading:
        return loading(loadingMessage);
      case LoadingState.loaded:
        if (data != null) {
          return loaded(data as T);
        }
        return error(const NetworkException('Invalid state: data is null'));
      case LoadingState.error:
        return error(
          this.error ?? const NetworkException('Unknown error occurred'),
        );
      case LoadingState.empty:
        return empty();
    }
  }

  /// Handles the state with optional callbacks (void return type)
  void whenVoid({
    Function()? initial,
    Function(String? message)? loading,
    Function(T data)? loaded,
    Function(AppException error)? error,
    Function()? empty,
  }) {
    when<void>(
      initial: initial ?? () {},
      loading: (msg) => loading?.call(msg),
      loaded: (data) => loaded?.call(data),
      error: (err) => error?.call(err),
      empty: empty ?? () {},
    );
  }
}
