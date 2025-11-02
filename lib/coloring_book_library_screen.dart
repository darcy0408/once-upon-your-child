// lib/coloring_book_library_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'coloring_book_service.dart';
import 'coloring_screen.dart';
import 'character_appearance.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ColoringBookLibraryScreen extends StatefulWidget {
  const ColoringBookLibraryScreen({super.key});

  @override
  State<ColoringBookLibraryScreen> createState() => _ColoringBookLibraryScreenState();
}

class _ColoringBookLibraryScreenState extends State<ColoringBookLibraryScreen> {
  final _coloringService = MockColoringBookService(); // Use mock for now
  List<ColoringPage> _coloringPages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadColoringPages();
  }

  Future<void> _loadColoringPages() async {
    setState(() => _isLoading = true);
    final pages = await _coloringService.getAllColoringPages();
    setState(() {
      _coloringPages = pages;
      _isLoading = false;
    });
  }

  Future<void> _deletePage(ColoringPage page) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Coloring Page?'),
        content: Text('Delete "${page.pageTitle}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _coloringService.deleteColoringPage(page.id);
      _loadColoringPages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coloring page deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _printPage(ColoringPage page) async {
    // Show options: Print or Download
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Print/Download Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download, color: Colors.blue),
              title: const Text('Download Image'),
              subtitle: const Text('Save to device'),
              onTap: () {
                Navigator.pop(context);
                _downloadImage(page);
              },
            ),
            ListTile(
              leading: const Icon(Icons.print, color: Colors.green),
              title: const Text('Print'),
              subtitle: const Text('Send to printer'),
              onTap: () {
                Navigator.pop(context);
                _printImage(page);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.orange),
              title: const Text('Share'),
              subtitle: const Text('Share with others'),
              onTap: () {
                Navigator.pop(context);
                _shareImage(page);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadImage(ColoringPage page) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Downloading...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Download image
      final response = await http.get(Uri.parse(page.imageUrl));
      final bytes = response.bodyBytes;

      // Get downloads directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/coloring_${page.id}.png';

      // Save file
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded to: $filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printImage(ColoringPage page) async {
    // In production, integrate with printing packages like 'printing'
    // For now, show instructions
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Print Instructions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('To print this coloring page:'),
            const SizedBox(height: 12),
            const Text('1. Download the image'),
            const Text('2. Open in your device\'s photo app'),
            const Text('3. Use the print option'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _downloadImage(page);
              },
              icon: const Icon(Icons.download),
              label: const Text('Download Now'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareImage(ColoringPage page) async {
    // Copy URL to clipboard
    await Clipboard.setData(ClipboardData(text: page.imageUrl));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 Image URL copied to clipboard!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coloring Book'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About Coloring Book'),
                  content: const Text(
                    'Create coloring pages from your stories!\n\n'
                    '• Color on screen with your finger\n'
                    '• Download and print pages\n'
                    '• Save your progress\n'
                    '• Share with friends\n\n'
                    'Tap "Generate" on any story to create coloring pages.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it!'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _coloringPages.isEmpty
              ? _buildEmptyState()
              : _buildColoringGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.palette, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No Coloring Pages Yet',
            style: TextStyle(
              fontSize: 24,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate coloring pages from your stories!',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Stories'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColoringGrid() {
    return RefreshIndicator(
      onRefresh: _loadColoringPages,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: _coloringPages.length,
        itemBuilder: (context, index) {
          final page = _coloringPages[index];
          return _buildColoringPageCard(page);
        },
      ),
    );
  }

  Widget _buildColoringPageCard(ColoringPage page) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ColoringScreen(coloringPage: page),
            ),
          ).then((_) => _loadColoringPages());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    page.imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.error, size: 40, color: Colors.red),
                      );
                    },
                  ),
                  // Actions overlay
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.print, color: Colors.white, size: 20),
                          onPressed: () => _printPage(page),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.6),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                          onPressed: () => _deletePage(page),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Title and info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    page.pageTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Created ${_formatDate(page.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
