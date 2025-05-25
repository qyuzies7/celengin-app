import 'package:flutter/material.dart';

class UserAvatarMenu extends StatelessWidget {
  final String? avatarAssetPath;
  final VoidCallback? onSignOut;

  const UserAvatarMenu({
    Key? key,
    this.avatarAssetPath,
    this.onSignOut,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'User Menu',
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: (value) {
        if (value == 1) {
          if (onSignOut != null) onSignOut!();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          value: 1,
          child: Row(
            children: const [
              Icon(Icons.logout, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text('Sign Out'),
            ],
          ),
        ),
      ],
      child: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.white,
        backgroundImage: avatarAssetPath != null
            ? AssetImage(avatarAssetPath!)
            : null,
        child: avatarAssetPath == null
            ? const Icon(Icons.person, color: Colors.grey)
            : null,
      ),
    );
  }
}
