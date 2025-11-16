import 'package:flutter/material.dart';
import '../utils/index.dart';

/// A reusable loading indicator widget
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final double strokeWidth;
  final Color? color;

  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 32.0,
    this.strokeWidth = 2.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicator = Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? theme.primaryColor,
          ),
        ),
      ),
    );

    if (message == null) return indicator;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 16.0),
        indicator,
        const SizedBox(height: 16.0),
        Text(
          message!,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// A widget that shows a loading indicator, error message, or content based on state
class StateBuilder<T> extends StatelessWidget {
  final DataState<T> state;
  final Widget Function(T data) builder;
  final Widget Function()? onInitial;
  final Widget Function(String? message)? onLoading;
  final Widget Function(AppException error)? onError;
  final Widget Function()? onEmpty;
  final bool showLoadingOnRefresh;
  final bool showErrorOnRefresh;

  const StateBuilder({
    super.key,
    required this.state,
    required this.builder,
    this.onInitial,
    this.onLoading,
    this.onError,
    this.onEmpty,
    this.showLoadingOnRefresh = true,
    this.showErrorOnRefresh = true,
  });

  @override
  Widget build(BuildContext context) {
    return state.when<Widget>(
      initial: () => onInitial?.call() ?? const SizedBox.shrink(),
      loading: (message) => onLoading?.call(message) ??
          Center(child: LoadingIndicator(message: message)),
      loaded: (data) => builder(data),
      error: (error) => onError?.call(error) ?? _buildErrorWidget(context, error),
      empty: () => onEmpty?.call() ?? _buildEmptyWidget(context),
    );
  }

  Widget _buildErrorWidget(BuildContext context, AppException error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error: ${error.message}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            if (showErrorOnRefresh) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  // Implement retry logic
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No items found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filter criteria',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
