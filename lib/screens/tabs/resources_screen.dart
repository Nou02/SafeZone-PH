import 'package:flutter/material.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resources')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: Icon(Icons.local_hospital_outlined),
            title: Text('Emergency Hotlines'),
            subtitle: Text('Call centers and local responders'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Safety Tips'),
            subtitle: Text('Guides for different scenarios'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.location_city_outlined),
            title: Text('Nearby Safe Zones'),
            subtitle: Text('Shelters and help centers'),
          ),
        ],
      ),
    );
  }
}











