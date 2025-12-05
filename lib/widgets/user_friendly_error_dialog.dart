import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';

class UserFriendlyErrorDialog extends StatelessWidget {
  final dynamic error;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const UserFriendlyErrorDialog({
    super.key,
    required this.error,
    this.onRetry,
    this.onCancel,
  });

  String _getFriendlyMessage() {
    final errorString = error.toString().toLowerCase();

    if (error is SocketException || errorString.contains('socket')) {
      return 'Hmm, looks like your internet is playing hide and seek. Check your connection and try again!';
    } else if (error is TimeoutException ||
errorString.contains('timeout')) {
      return 'This is taking longer than usual. Our story engine might be catching its breath. Want to try again?';
    } else if (errorString.contains('403') ||
errorString.contains('api key')) {
      return 'There\'s a hiccup with our story magic. Please try again in a moment!';
    } else if (errorString.contains('500') ||
errorString.contains('server')) {
      return 'Our story engine is taking a quick break. Give it a few seconds and try again!';
    }

    return 'Something unexpected happened. Don\'t worry, let\'s try creating your story again!';
  }

  String _getSuggestedAction() {
    final errorString = error.toString().toLowerCase();

    if (error is SocketException || errorString.contains('socket')) {
      return '💡 Check that WiFi or mobile data is turned on';
    } else if (error is TimeoutException ||
errorString.contains('timeout')) {
      return '💡 The app might be slow right now. Wait 30 seconds and retry';
    } else if (errorString.contains('500')) {
      return '💡 Our servers are busy. Try again in a minute';
    }

    return '💡 Close and reopen the app, then give it another try';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius:
BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.orange, size: 32),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Oops!', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_getFriendlyMessage()}\n\nDebug: $error',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getSuggestedAction(),
              style: TextStyle(fontSize: 14, color: Colors.blue[900]),
            ),
          ),
        ],
      ),
      actions: [
        if (onCancel != null)
          TextButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        if (onRetry != null)
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 20,
vertical: 12),
            ),
          ),
      ],
    );
  }
}
