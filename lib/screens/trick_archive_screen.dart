import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/spot_video.dart';
import '../models/post.dart';
import '../utils/error_helper.dart';
import 'trick_submission_dialog.dart';

class TrickArchiveScreen extends StatefulWidget {
  final MapPost spot;

  const TrickArchiveScreen({super.key, required this.spot});

  @override
  State<TrickArchiveScreen> createState() => _TrickArchiveScreenState();
}

class _TrickArchiveScreenState extends State<TrickArchiveScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SpotVideo> _videos = [];
  bool _isLoading = true;
  String _sortBy = 'newest';
  String _selectedCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchArchive();
  }

  Future<void> _fetchArchive() async {
    setState(() => _isLoading = true);
    try {
      final videos = await SupabaseService.getSpotArchive(
        widget.spot.id!,
        searchQuery: _searchController.text.trim(),
        category: _selectedCategory == 'ALL' ? null : _selectedCategory.toLowerCase(),
      );
      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error loading archive: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSubmissionDialog() {
    showDialog(
      context: context,
      builder: (context) => TrickSubmissionDialog(
        spotId: widget.spot.id!,
        onTrickSubmitted: () {
          _fetchArchive();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);
    const matrixBlack = Color(0xFF000000);

    return Scaffold(
      backgroundColor: matrixBlack,
      appBar: AppBar(
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'TRICK ARCHIVE',
              style: TextStyle(
                color: matrixGreen,
                fontFamily: 'monospace',
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              widget.spot.title.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: matrixBlack,
        iconTheme: const IconThemeData(color: matrixGreen),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: matrixGreen),
            onSelected: (value) {
              setState(() => _sortBy = value);
              _fetchArchive();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'newest', child: Text('Newest')),
              const PopupMenuItem(value: 'upvotes', child: Text('Most Hyped')),
              const PopupMenuItem(value: 'technical', child: Text('Most Technical')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'SEARCH TRICKS (E.G. KICKFLIP)...',
                hintStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.5)),
                prefixIcon: const Icon(Icons.search, color: matrixGreen),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.3)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen),
                ),
              ),
              style: const TextStyle(color: matrixGreen, fontFamily: 'monospace'),
              onSubmitted: (_) => _fetchArchive(),
            ),
          ),
          
          // Tags/Categories Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['ALL', 'LINE', 'FLIP', 'GRIND', 'SLIDE', 'MANUAL', 'GAP'].map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat, style: const TextStyle(fontSize: 10)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                      _fetchArchive();
                    },
                    backgroundColor: matrixBlack,
                    selectedColor: matrixGreen.withValues(alpha: 0.2),
                    showCheckmark: false,
                    side: BorderSide(
                      color: isSelected ? matrixGreen : matrixGreen.withValues(alpha: 0.3),
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : matrixGreen,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Archive List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: matrixGreen))
                : _videos.isEmpty
                    ? Center(
                        child: Text(
                          'NO CLIPS FOUND IN ARCHIVE',
                          style: TextStyle(color: matrixGreen.withValues(alpha: 0.5), fontFamily: 'monospace'),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _videos.length,
                        itemBuilder: (context, index) {
                          final video = _videos[index];
                          return _buildTrickCard(video);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSubmissionDialog,
        backgroundColor: matrixGreen,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('LOG TRICK TO ARCHIVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      ),
    );
  }

  Widget _buildTrickCard(SpotVideo video) {
    const matrixGreen = Color(0xFF00FF41);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: matrixGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              image: video.thumbnailUrl != null 
                  ? DecorationImage(image: NetworkImage(video.thumbnailUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: const Center(
              child: Icon(Icons.play_circle_outline, color: matrixGreen, size: 48),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      video.displayTitle.toUpperCase(),
                      style: const TextStyle(
                        color: matrixGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: matrixGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${video.upvotes} HYPE',
                        style: const TextStyle(color: matrixGreen, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 12, color: Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(
                      video.skaterName ?? 'LOCAL SKATER',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      video.timeAgo,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                    ),
                  ],
                ),
                if (video.description != null && video.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    video.description!,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
