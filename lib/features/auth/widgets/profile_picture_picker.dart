import 'package:flutter/material.dart';

class ProfilePicturePicker extends StatelessWidget {
  final void Function()? onPick;
  final String? imageUrl;
  const ProfilePicturePicker({Key? key, this.onPick, this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: CircleAvatar(
        radius: 40,
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
        child: imageUrl == null ? const Icon(Icons.camera_alt, size: 40) : null,
      ),
    );
  }
} 