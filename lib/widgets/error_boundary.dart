import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(
          BuildContext context, Object error, StackTrace? stackTrace)?
      fallbackBuilder;
  final VoidCallback? onRetry;
  final void Function(Object error, StackTrace stackTrace)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallbackBuilder,
    this.onRetry,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;
  FlutterExceptionHandler? _previousHandler;

  @override
  void initState() {
    super.initState();
    _previousHandler = FlutterError.onError;
    FlutterError.onError = _handleFlutterError;
  }

  @override
  void dispose() {
    FlutterError.onError = _previousHandler;
    super.dispose();
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    _previousHandler?.call(details);

    if (!mounted || _error != null) return;

    setState(() {
      _error = details.exception;
      _stackTrace = details.stack;
    });

    widget.onError?.call(
      details.exception,
      details.stack ?? StackTrace.empty,
    );
    _logError(details);
  }

  void _logError(FlutterErrorDetails details) {
    debugPrint('Caught error in ErrorBoundary: ${details.exception}');
    debugPrintStack(stackTrace: details.stack);
  }

  void _resetError() {
    if (!mounted) return;
    setState(() {
      _error = null;
      _stackTrace = null;
    });
    if (widget.onRetry != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => widget.onRetry?.call());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final fallback = widget.fallbackBuilder?.call(
        context,
        _error!,
        _stackTrace,
      );
      if (fallback != null) return fallback;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Oops! Something went wrong.',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error.toString(),
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              if (_stackTrace != null) ...[
                const SizedBox(height: 16),
                ExpansionTile(
                  title: const Text('Details (for debugging)'),
                  children: [
                    Text(
                      (_stackTrace ?? StackTrace.empty).toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _resetError,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }
    return widget.child;
  }
}
