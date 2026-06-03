import 'package:flutter/material.dart';

import '../config.dart';
import '../services/braincloud_service.dart';

/// Small unobtrusive version label for the bottom-left of a screen.
/// Shows the app version (from [BrainCloudConfig.appVersion]) and the
/// brainCloud Dart SDK version.
class VersionFooter extends StatelessWidget {
  const VersionFooter({super.key, required this.bc});

  final BrainCloudService bc;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 0, 6),
        child: Text(
          'v${BrainCloudConfig.appVersion}  •  brainCloud ${bc.sdkVersion}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
