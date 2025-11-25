import 'package:flutter/material.dart';

/// A reusable profile header widget with avatar, username, and edit capabilities
class ProfileHeader extends StatelessWidget {
  final String? username;
  final String? avatarUrl;
  final String? email;
  final bool isUploadingImage;
  final VoidCallback? onEditUsername;
  final VoidCallback? onUploadImage;
  final VoidCallback? onSettingsTap;

  const ProfileHeader({
    super.key,
    this.username,
    this.avatarUrl,
    this.email,
    this.isUploadingImage = false,
    this.onEditUsername,
    this.onUploadImage,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = username?.isNotEmpty == true 
        ? username! 
        : email?.split('@').first ?? 'User';
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildAvatar(context, displayName),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onEditUsername != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: onEditUsername,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Edit username',
                      ),
                    ],
                  ],
                ),
                if (email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    email!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onSettingsTap != null)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: onSettingsTap,
              tooltip: 'Settings',
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, String displayName) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).primaryColor,
              width: 3,
            ),
          ),
          child: CircleAvatar(
            radius: 40,
            backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(
                    displayName[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  )
                : null,
          ),
        ),
        if (onUploadImage != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
              child: isUploadingImage
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.camera_alt, size: 16),
                      color: Colors.white,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      onPressed: onUploadImage,
                      tooltip: 'Change profile picture',
                    ),
            ),
          ),
      ],
    );
  }
}

/// A simplified profile avatar widget for use in lists or smaller contexts
class ProfileAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const ProfileAvatar({
    super.key,
    this.avatarUrl,
    required this.displayName,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Theme.of(context).primaryColor.withValues(alpha: 0.1),
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      child: avatarUrl == null
          ? Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
                color: foregroundColor ?? Theme.of(context).primaryColor,
              ),
            )
          : null,
    );
  }
}
