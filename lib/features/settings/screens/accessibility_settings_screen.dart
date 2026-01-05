import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/accessibility_service.dart';

class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Accessibility'),
        backgroundColor: AppColors.sidebar,
      ),
      body: Consumer<AccessibilityService>(
        builder: (context, accessibilityService, child) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Font Size
                _buildSection(
                  'Font Size',
                  Icons.text_fields,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adjust text size: ${(accessibilityService.fontSizeMultiplier * 100).toInt()}%',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      Slider(
                        value: accessibilityService.fontSizeMultiplier,
                        min: AccessibilityService.minFontSize,
                        max: AccessibilityService.maxFontSize,
                        divisions: 14,
                        label: '${(accessibilityService.fontSizeMultiplier * 100).toInt()}%',
                        onChanged: (value) {
                          accessibilityService.setFontSizeMultiplier(value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // High Contrast
                _buildSection(
                  'High Contrast',
                  Icons.contrast,
                  SwitchListTile(
                    title: const Text(
                      'Enable high contrast mode',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Increases contrast for better visibility',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    value: accessibilityService.highContrastMode,
                    onChanged: (_) => accessibilityService.toggleHighContrast(),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),

                // Dyslexia-Friendly Font
                _buildSection(
                  'Dyslexia-Friendly Font',
                  Icons.font_download,
                  SwitchListTile(
                    title: const Text(
                      'Use dyslexia-friendly font',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Easier to read for users with dyslexia',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    value: accessibilityService.dyslexiaFriendlyFont,
                    onChanged: (_) => accessibilityService.toggleDyslexiaFont(),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),

                // Reduce Animations
                _buildSection(
                  'Reduce Animations',
                  Icons.animation,
                  SwitchListTile(
                    title: const Text(
                      'Reduce motion',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Minimizes animations throughout the app',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    value: accessibilityService.reduceAnimations,
                    onChanged: (_) => accessibilityService.toggleReduceAnimations(),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 24),

                // Preview Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.sidebar,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.preview, color: AppColors.primary, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Preview',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'This is how text will appear with your current settings.',
                        style: accessibilityService.getAdjustedTextStyle(
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Font size: ${(accessibilityService.fontSizeMultiplier * 100).toInt()}%',
                        style: accessibilityService.getAdjustedTextStyle(
                          TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Reset Button
                Center(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restore),
                    label: const Text('Reset to Defaults'),
                    onPressed: () {
                      accessibilityService.resetToDefaults();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings reset to defaults')),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
  }

  Widget _buildSection(String title, IconData icon, Widget content) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }
}
