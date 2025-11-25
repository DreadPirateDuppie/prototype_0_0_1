import 'package:flutter/material.dart';

/// A standardized loading widget for consistent UI across the app
class LoadingWidget extends StatelessWidget {
  final String? message;
  final Color? color;
  final double size;

  const LoadingWidget({
    super.key,
    this.message,
    this.color,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? Theme.of(context).primaryColor,
              ),
              strokeWidth: 3,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// A standardized error widget with retry functionality
class ErrorDisplayWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  final Color? iconColor;

  const ErrorDisplayWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: iconColor ?? Colors.red.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A standardized empty state widget
class EmptyStateWidget extends StatelessWidget {
  final String message;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.message,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.iconColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: iconColor ?? Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A wrapper widget that handles loading, error, and content states
class AsyncStateWidget<T> extends StatelessWidget {
  final Future<T>? future;
  final T? data;
  final bool isLoading;
  final String? error;
  final Widget Function(T data) builder;
  final Widget? loadingWidget;
  final Widget Function(String error)? errorBuilder;
  final VoidCallback? onRetry;
  final String? loadingMessage;

  const AsyncStateWidget({
    super.key,
    this.future,
    this.data,
    this.isLoading = false,
    this.error,
    required this.builder,
    this.loadingWidget,
    this.errorBuilder,
    this.onRetry,
    this.loadingMessage,
  });

  @override
  Widget build(BuildContext context) {
    // If using manual state management
    if (future == null) {
      if (isLoading) {
        return loadingWidget ?? LoadingWidget(message: loadingMessage);
      }
      if (error != null) {
        return errorBuilder?.call(error!) ?? 
            ErrorDisplayWidget(message: error!, onRetry: onRetry);
      }
      if (data != null) {
        return builder(data as T);
      }
      return const SizedBox.shrink();
    }

    // If using FutureBuilder
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget ?? LoadingWidget(message: loadingMessage);
        }
        
        if (snapshot.hasError) {
          return errorBuilder?.call(snapshot.error.toString()) ?? 
              ErrorDisplayWidget(
                message: snapshot.error.toString(),
                onRetry: onRetry,
              );
        }
        
        if (snapshot.hasData) {
          return builder(snapshot.data as T);
        }
        
        return const EmptyStateWidget(
          message: 'No data available',
          icon: Icons.inbox_outlined,
        );
      },
    );
  }
}

/// A simple refresh indicator wrapper with standardized behavior
class RefreshableContent extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? indicatorColor;

  const RefreshableContent({
    super.key,
    required this.child,
    required this.onRefresh,
    this.indicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: indicatorColor ?? Theme.of(context).primaryColor,
      child: child,
    );
  }
}
