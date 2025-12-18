import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test² Dashboard'),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: 0,
            extended: true,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home),
                label: Text('Overview'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.description),
                label: Text('Past Papers'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          const Expanded(
            child: Center(
              child: Text('Topic-Based Past Papers coming soon...'),
            ),
          ),
        ],
      ),
    );
  }
}

