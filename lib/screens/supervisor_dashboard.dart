import 'package:flutter/material.dart';

class SupervisorDashboard extends StatelessWidget {
  const SupervisorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Supervisor Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [

            _buildMenuButton(
              context: context,
              title: "Create Form",
              subtitle: "Build a custom data collection form",
              icon: Icons.note_add,
              onTap: () => Navigator.pushNamed(context, "/formBuilder"),
            ),

            const SizedBox(height: 16),

            _buildMenuButton(
              context: context,
              title: "Organize Team",
              subtitle: "Select field workers for deployment",
              icon: Icons.group,
              onTap: () => Navigator.pushNamed(context, "/organizeTeam"),
            ),

            const SizedBox(height: 16),

            _buildMenuButton(
              context: context,
              title: "Live Data Collection",
              subtitle: "View real-time submissions from field agents",
              icon: Icons.published_with_changes,
              onTap: () => Navigator.pushNamed(context, "/liveSession"),
            ),

            const SizedBox(height: 16),

            _buildMenuButton(
              context: context,
              title: "Reports",
              subtitle: "Review collected datasets & analytics",
              icon: Icons.insert_chart,
              onTap: () => Navigator.pushNamed(context, "/reports"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),

          child: Row(
            children: [
              Icon(icon, size: 36),
              const SizedBox(width: 20),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        )
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        )
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
