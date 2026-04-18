import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../../data/models/dish.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../logic/match_provider.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../data/models/couple.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CoupleProvider>().loadCouple();
      if (!mounted) return;
      context.read<MatchProvider>().loadMatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    final MatchProvider matchProvider = context.watch<MatchProvider>();
    final CoupleProvider coupleProvider = context.watch<CoupleProvider>();
    final String? currentUserId = context.watch<AuthProvider>().currentUser?.id;
    final CoupleMemberProfile? partner = _resolvePartner(
      members: coupleProvider.currentCouple?.memberProfiles,
      currentUserId: currentUserId,
    );
    final String partnerName = _resolvePartnerName(partner);
    final String? partnerAvatarUrl = partner?.avatarUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: AppDimensions.paddingS),
              _Header(
                partnerName: partnerName,
                partnerAvatarUrl: partnerAvatarUrl,
              ),
              const SizedBox(height: AppDimensions.paddingL),
              Expanded(child: _buildBody(matchProvider)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(MatchProvider matchProvider) {
    if (matchProvider.isLoading && matchProvider.matches.isEmpty) {
      return ListView.builder(
        itemCount: 4,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: AppDimensions.paddingS),
          child: ShimmerListTile(),
        ),
      );
    }

    if (matchProvider.error != null && matchProvider.matches.isEmpty) {
      return ErrorState(
        message: matchProvider.error!,
        onRetry: () => context.read<MatchProvider>().loadMatches(),
      );
    }

    if (matchProvider.matches.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => context.read<MatchProvider>().loadMatches(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const <Widget>[
            SizedBox(height: 120),
            EmptyState(
              icon: Icons.favorite_border,
              title: AppStrings.noMatchesYet,
              subtitle: AppStrings.swipeTogether,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<MatchProvider>().loadMatches(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: matchProvider.matches.length,
        itemBuilder: (BuildContext context, int index) {
          final dish = matchProvider.matches[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => context.push('/recipe-detail/${dish.id}', extra: dish),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFEDEBEA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            dish.name.isEmpty ? 'Untitled dish' : dish.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 34 * 0.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dish.description.isEmpty ? 'No description available.' : dish.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _buildChips(dish),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                '${dish.cookTime <= 0 ? 0 : dish.cookTime} min.',
                                style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Icon(Icons.people_outline, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                '${dish.servings.isEmpty ? '2' : dish.servings} servings',
                                style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _MatchDishImage(
                      imageUrl: dish.imageUrl,
                      isBookmarked: dish.popular,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildChips(Dish dish) {
    final List<String> candidates = <String>[
      dish.cuisine,
      dish.type,
    ].where((String value) => value.trim().isNotEmpty).toList();

    if (candidates.isEmpty) {
      candidates.add('Dish');
    }

    return candidates.take(2).map(_TagChip.new).toList();
  }

  CoupleMemberProfile? _resolvePartner({
    List<CoupleMemberProfile>? members,
    String? currentUserId,
  }) {
    if (members == null || members.isEmpty || currentUserId == null || currentUserId.isEmpty) {
      return null;
    }

    for (final CoupleMemberProfile member in members) {
      if (member.id.isNotEmpty && member.id != currentUserId) {
        return member;
      }
    }
    return null;
  }

  String _resolvePartnerName(CoupleMemberProfile? partner) {
    final String? displayName = partner?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    return AppStrings.yourPartner;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.partnerName,
    this.partnerAvatarUrl,
  });

  final String partnerName;
  final String? partnerAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.matches,
          style: GoogleFonts.pacifico(
            fontSize: 38,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 1),
        Row(
          children: <Widget>[
            Text(
              '${AppStrings.matchesWith} ',
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            Flexible(
              child: Text(
                partnerName,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 56 * 0.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _PartnerAvatar(
              partnerName: partnerName,
              avatarUrl: partnerAvatarUrl,
            ),
          ],
        ),
      ],
    );
  }
}

class _PartnerAvatar extends StatelessWidget {
  const _PartnerAvatar({
    required this.partnerName,
    this.avatarUrl,
  });

  final String partnerName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final String initials = partnerName.trim().isEmpty ? '?' : partnerName.trim()[0].toUpperCase();
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: ImageUtils.getImageUrl(avatarUrl),
          width: 30,
          height: 30,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _buildFallback(initials),
        ),
      );
    }
    return _buildFallback(initials);
  }

  Widget _buildFallback(String initials) {
    return CircleAvatar(
      radius: 15,
      backgroundColor: const Color(0xFFE6DFDC),
      child: Text(
        initials,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _MatchDishImage extends StatelessWidget {
  const _MatchDishImage({
    required this.imageUrl,
    required this.isBookmarked,
  });

  final String imageUrl;
  final bool isBookmarked;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: CachedNetworkImage(
            imageUrl: ImageUtils.getImageUrl(imageUrl),
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              width: 120,
              height: 120,
              color: const Color(0xFFF1EFEE),
              alignment: Alignment.center,
              child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textSecondary),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Icon(
            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            size: 18,
            color: isBookmarked ? const Color(0xFFFF5D33) : Colors.white,
          ),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF858585), width: 1.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF666666),
        ),
      ),
    );
  }
}
