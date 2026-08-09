import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme_extensions.dart';
import '../../../../data/models/couple.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../shared/widgets/media/safe_avatar_image.dart';

class SessionResumeChoiceScreen extends StatefulWidget {
  const SessionResumeChoiceScreen({
    super.key,
    required this.isSoloMode,
    required this.onLoadPreviousSetup,
    required this.onUsePreviousFilter,
    required this.onStartNew,
    this.partner,
  });

  final bool isSoloMode;
  final Future<LastFilterPreset?> Function() onLoadPreviousSetup;
  final Future<void> Function(LastFilterPreset?) onUsePreviousFilter;
  final VoidCallback onStartNew;
  final CoupleMemberProfile? partner;

  @override
  State<SessionResumeChoiceScreen> createState() => _SessionResumeChoiceScreenState();
}

class _SessionResumeChoiceScreenState extends State<SessionResumeChoiceScreen> {
  late Future<LastFilterPreset?> _presetFuture;
  LastFilterPreset? _preset;
  bool _isContinuing = false;

  @override
  void initState() {
    super.initState();
    _loadPreset();
  }

  @override
  void didUpdateWidget(covariant SessionResumeChoiceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSoloMode != widget.isSoloMode || oldWidget.partner?.id != widget.partner?.id) {
      _loadPreset();
    }
  }

  void _loadPreset() {
    _presetFuture = widget.onLoadPreviousSetup().then((LastFilterPreset? preset) {
      _preset = preset;
      return preset;
    });
  }

  Future<void> _handleContinue() async {
    if (_isContinuing) return;
    setState(() => _isContinuing = true);
    try {
      final LastFilterPreset? preset = _preset ?? await _presetFuture;
      await widget.onUsePreviousFilter(preset);
    } finally {
      if (mounted) setState(() => _isContinuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    final String partnerName = _partnerName(widget.partner);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Image.asset(
              'assets/media/Session_complete.png',
              height: 230,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Session complete',
            style: GoogleFonts.fredoka(
              fontSize: 35,
              fontWeight: FontWeight.w700,
              height: 1.05,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Would you like to continue with previous setup or start a new session?',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: 15,
              height: 1.35,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isContinuing ? null : _handleContinue,
              style: OutlinedButton.styleFrom(
                backgroundColor: colors.background,
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.primary, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              child: Text(_isContinuing ? 'Continuing…' : 'Continue as before'),
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onStartNew,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.buttonPrimaryBackground,
                foregroundColor: colors.buttonPrimaryText,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              child: const Text('Create a new session'),
            ),
          ),
          const SizedBox(height: 26),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  widget.isSoloMode ? 'Solo' : 'With $partnerName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: colors.textPrimary),
                ),
              ),
              if (!widget.isSoloMode) ...<Widget>[
                const SizedBox(width: 8),
                _PartnerAvatar(partner: widget.partner, partnerName: partnerName),
              ],
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<LastFilterPreset?>(
            future: _presetFuture,
            builder: (BuildContext context, AsyncSnapshot<LastFilterPreset?> snapshot) {
              final LastFilterPreset? preset = snapshot.data ?? _preset;
              if (snapshot.connectionState == ConnectionState.waiting && preset == null) {
                return _FilterSummaryCard.loading();
              }
              return _FilterSummaryCard.fromPreset(preset);
            },
          ),
        ],
      ),
    );
  }
}

class _PartnerAvatar extends StatelessWidget {
  const _PartnerAvatar({required this.partner, required this.partnerName});

  final CoupleMemberProfile? partner;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    final String? avatarUrl = partner?.avatarUrl;
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      return ClipOval(child: SafeAvatarImage(imageUrl: avatarUrl, size: 24));
    }
    final FoodMatchThemeColors colors = context.fmColors;
    return CircleAvatar(
      radius: 12,
      backgroundColor: colors.primarySoft,
      child: Text(
        partnerName.isEmpty ? '?' : partnerName.substring(0, 1).toUpperCase(),
        style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w900, color: colors.primary),
      ),
    );
  }
}

class _FilterSummaryCard extends StatelessWidget {
  const _FilterSummaryCard({
    required this.dishRegisters,
    required this.cuisines,
    required this.exclusions,
    this.isLoading = false,
  });

  factory _FilterSummaryCard.fromPreset(LastFilterPreset? preset) => _FilterSummaryCard(
        dishRegisters: preset?.dishRegisters ?? const <String>[],
        cuisines: preset?.cuisines ?? const <String>[],
        exclusions: preset?.exclusions ?? const <String>[],
      );

  factory _FilterSummaryCard.loading() => const _FilterSummaryCard(
        dishRegisters: <String>[],
        cuisines: <String>[],
        exclusions: <String>[],
        isLoading: true,
      );

  final List<String> dishRegisters;
  final List<String> cuisines;
  final List<String> exclusions;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: <Widget>[
          _FilterSection(icon: Icons.restaurant_menu, label: 'Meal format:', values: dishRegisters, type: _FilterChipType.cuisine, isLoading: isLoading),
          Divider(height: 1, color: colors.divider),
          _FilterSection(icon: Icons.room_service_outlined, label: 'Cuisine:', values: cuisines, type: _FilterChipType.cuisine, isLoading: isLoading),
          Divider(height: 1, color: colors.divider),
          _FilterSection(icon: Icons.do_not_disturb_alt_outlined, label: 'Exceptions:', values: exclusions, type: _FilterChipType.exception, isLoading: isLoading),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.icon, required this.label, required this.values, required this.type, this.isLoading = false});

  final IconData icon;
  final String label;
  final List<String> values;
  final _FilterChipType type;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    final List<String> chips = isLoading ? <String>['Loading...'] : values.isEmpty ? <String>['None'] : values;
    final _ChipColors chipColors = isLoading || values.isEmpty ? _emptyChipColors(colors) : _filterChipColors(context, type);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: chipColors.foreground, size: 21),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.nunito(fontSize: 15, color: colors.textMuted, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: chips
                .map(
                  (String value) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: chipColors.background,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: chipColors.border),
                    ),
                    child: Text(
                      isLoading || values.isEmpty ? value : _formatOptionLabel(value),
                      style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: chipColors.foreground),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

String _partnerName(CoupleMemberProfile? partner) {
  final String? email = partner?.email;
  final String? emailPrefix = email == null || !email.contains('@') ? email : email.split('@').first;
  final List<String?> candidates = <String?>[partner?.displayName, partner?.name, partner?.username, emailPrefix];
  for (final String? candidate in candidates) {
    final String value = candidate?.trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return 'your partner';
}

String _formatOptionLabel(String value) => value
    .trim()
    .replaceAll('_', ' ')
    .split(RegExp(r'\s+'))
    .where((String word) => word.isNotEmpty)
    .map((String word) => word[0].toUpperCase() + word.substring(1))
    .join(' ');


enum _FilterChipType { cuisine, mood, exception }

class _ChipColors {
  const _ChipColors({required this.background, required this.foreground, required this.border});

  final Color background;
  final Color foreground;
  final Color border;
}

_ChipColors _emptyChipColors(FoodMatchThemeColors colors) => _ChipColors(
      background: colors.chipBackground,
      foreground: colors.textMuted,
      border: colors.chipBorder,
    );

_ChipColors _filterChipColors(BuildContext context, _FilterChipType type) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  if (isDark) {
    switch (type) {
      case _FilterChipType.cuisine:
        return const _ChipColors(background: Color(0xFF4A3218), foreground: Color(0xFFF0A03A), border: Color(0xFF5A3A1D));
      case _FilterChipType.mood:
        return const _ChipColors(background: Color(0xFF4A462C), foreground: Color(0xFFE2C403), border: Color(0xFF5A552F));
      case _FilterChipType.exception:
        return const _ChipColors(background: Color(0xFF4A211B), foreground: Color(0xFFFF4E2F), border: Color(0xFF5A2A22));
    }
  }
  switch (type) {
    case _FilterChipType.cuisine:
      return const _ChipColors(background: Color(0xFFFFEDDE), foreground: Color(0xFFEE8C04), border: Color(0xFFFFD7BB));
    case _FilterChipType.mood:
      return const _ChipColors(background: Color(0xFFFFF8C7), foreground: Color(0xFFC39A00), border: Color(0xFFFFECB0));
    case _FilterChipType.exception:
      return const _ChipColors(background: Color(0xFFFFE4DF), foreground: Color(0xFFFF4E2F), border: Color(0xFFFFC9C0));
  }
}
