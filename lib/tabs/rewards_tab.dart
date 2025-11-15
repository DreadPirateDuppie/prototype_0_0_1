import 'package:flutter/material.dart';

class RewardsTab extends StatelessWidget {
  const RewardsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rewards')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Banner explaining this is a preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Rewards system is coming soon! This is a preview.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.amber.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Your Points',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '0',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start earning by creating posts!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'How to Earn Points',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.add_location, color: Colors.green),
                      title: const Text('Create a post'),
                      subtitle: const Text('Earn 10 points'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.favorite, color: Colors.red),
                      title: const Text('Get a like'),
                      subtitle: const Text('Earn 2 points'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.star, color: Colors.amber),
                      title: const Text('Get a rating'),
                      subtitle: const Text('Earn 5 points'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.photo_camera, color: Colors.blue),
                      title: const Text('Add a photo'),
                      subtitle: const Text('Earn 3 points'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Available Rewards (Preview)',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                itemBuilder: (context, index) {
                  final rewards = [
                    {'name': 'Bronze Badge', 'points': 500},
                    {'name': 'Silver Badge', 'points': 1000},
                    {'name': 'Gold Badge', 'points': 2500},
                    {'name': 'Platinum Badge', 'points': 5000},
                  ];
                  
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.card_giftcard,
                        color: Colors.deepPurple.shade300,
                      ),
                      title: Text(rewards[index]['name'] as String),
                      subtitle: Text('${rewards[index]['points']} points'),
                      trailing: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Rewards system coming soon!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Text('Coming Soon'),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
