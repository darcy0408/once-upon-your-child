// lib/illustrated_story_viewer.dart

import 'package:flutter/material.dart';
import 'story_illustration_service.dart';
import 'story_narrator.dart';

class IllustratedStoryViewer extends StatefulWidget {
  final String title;
  final String storyText;
  final List<StoryIllustration> illustrations;
  final String? characterName;

  const IllustratedStoryViewer({
    super.key,
    required this.title,
    required this.storyText,
    required this.illustrations,
    this.characterName,
  });

  @override
  State<IllustratedStoryViewer> createState() => _IllustratedStoryViewerState();
}

class _IllustratedStoryViewerState extends State<IllustratedStoryViewer> {
  final PageController _pageController = PageController();
  late final StoryNarrator _narrator;
  int _currentPage = 0;
  bool _isNarrating = false;

  @override
  void initState() {
    super.initState();
    _narrator = StoryNarrator();
    _setupNarrator();
    _splitStoryIntoPages();
  }

  void _setupNarrator() {
    _narrator.onPlayingStateChanged = (playing) {
      setState(() {
        _isNarrating = playing;
      });
    };
  }

  List<String> _storyPages = [];

  void _splitStoryIntoPages() {
    // Split story based on illustrations
    if (widget.illustrations.isEmpty) {
      _storyPages = [widget.storyText];
      return;
    }

    final sentences = widget.storyText.split(RegExp(r'[.!?]+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    final pagesCount = widget.illustrations.length + 1; // illustrations + final page
    final sentencesPerPage = sentences.length ~/ pagesCount;

    _storyPages = [];
    for (int i = 0; i < pagesCount; i++) {
      final startIndex = i * sentencesPerPage;
      final endIndex = (i == pagesCount - 1)
          ? sentences.length
          : (i + 1) * sentencesPerPage;

      if (startIndex < sentences.length) {
        final pageSentences = sentences.sublist(
          startIndex,
          endIndex.clamp(0, sentences.length),
        );
        _storyPages.add(pageSentences.join('. ') + '.');
      }
    }
  }

  @override
  void dispose() {
    _narrator.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(_isNarrating ? Icons.pause : Icons.play_arrow),
            onPressed: _toggleNarration,
            tooltip: _isNarrating ? 'Pause' : 'Play',
          ),
        ],
      ),
      body: Column(
        children: [
          // Page indicator
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.purple.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Page ${_currentPage + 1} of ${_storyPages.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),

          // Story pages with illustrations
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
                if (_isNarrating) {
                  _narrator.stopNarration();
                }
              },
              itemCount: _storyPages.length,
              itemBuilder: (context, index) {
                return _buildStoryPage(index);
              },
            ),
          ),

          // Navigation controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentPage > 0 ? _previousPage : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _toggleNarration,
                  icon: Icon(_isNarrating ? Icons.pause : Icons.volume_up),
                  label: Text(_isNarrating ? 'Pause' : 'Read Aloud'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isNarrating ? Colors.orange : Colors.green,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _currentPage < _storyPages.length - 1 ? _nextPage : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryPage(int pageIndex) {
    final hasIllustration = pageIndex < widget.illustrations.length;
    final storyText = _storyPages[pageIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Illustration (if available for this page)
          if (hasIllustration) ...[
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  widget.illustrations[pageIndex].imageUrl,
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 300,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 300,
                      color: Colors.grey.shade200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported, size: 60, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Image not available',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Story text
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                storyText,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.8,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.justify,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Fun fact or tip (for last page)
          if (pageIndex == _storyPages.length - 1) ...[
            Card(
              color: Colors.amber.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'The End!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.characterName != null
                                ? 'Great job reading about ${widget.characterName}!'
                                : 'Great job reading this story!',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _storyPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _toggleNarration() async {
    if (_isNarrating) {
      await _narrator.pauseNarration();
    } else {
      final pageText = _storyPages[_currentPage];
      await _narrator.startNarration(pageText);
    }
  }
}
