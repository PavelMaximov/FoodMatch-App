import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../data/models/dish.dart';
import '../../../../data/repositories/dish_repository.dart';
import '../../../../data/repositories/upload_repository.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/validators.dart';

class AddDishScreen extends StatefulWidget {
  const AddDishScreen({super.key});

  @override
  State<AddDishScreen> createState() => _AddDishScreenState();
}

class _AddDishScreenState extends State<AddDishScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _cuisineController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingMyDishes = false;
  List<Dish> _myDishes = <Dish>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyDishes();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _cuisineController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadMyDishes() async {
    setState(() => _isLoadingMyDishes = true);
    try {
      final DishRepository dishRepository = context.read<DishRepository>();
      final String? currentUserId = context.read<AuthProvider>().currentUser?.id;
      final List<Dish> dishes = await dishRepository.getDishes();
      _myDishes = dishes.where((Dish dish) => dish.createdBy == currentUserId).toList();
    } catch (_) {
      _myDishes = <Dish>[];
    } finally {
      if (mounted) {
        setState(() => _isLoadingMyDishes = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final UploadRepository uploadRepository = context.read<UploadRepository>();
      final String url = await uploadRepository.uploadImage(File(image.path));
      _imageUrlController.text = url;
    } catch (_) {
      if (!mounted) return;
      SnackBarUtils.showError(context, AppStrings.unableToUploadImage);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final DishRepository dishRepository = context.read<DishRepository>();

      await dishRepository.createDish(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        cuisine: _cuisineController.text.trim(),
        tags: const <String>[],
      );

      _formKey.currentState!.reset();
      _titleController.clear();
      _descriptionController.clear();
      _cuisineController.clear();
      _imageUrlController.clear();

      await _loadMyDishes();
      if (mounted) {
        SnackBarUtils.showSuccess(context, AppStrings.dishAdded);
      }
    } catch (_) {
      if (mounted) {
        SnackBarUtils.showError(context, AppStrings.failedToAddDish);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
          child: Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                const SizedBox(height: AppDimensions.paddingS),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(Icons.add_circle, color: AppColors.primary),
                    const SizedBox(width: AppDimensions.paddingS),
                    Text(
                      AppStrings.addYourDish,
                      style: GoogleFonts.pacifico(
                        fontSize: 28,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.paddingS),
                Text(
                  AppStrings.addDishDesc,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppDimensions.paddingL),
                AppTextField(
                  hint: AppStrings.nameOfDish,
                  controller: _titleController,
                  required: true,
                  validator: (String? value) => Validators.required(value, 'Dish name'),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  hint: AppStrings.kitchenStyle,
                  controller: _cuisineController,
                  required: true,
                  validator: (String? value) => Validators.required(value, 'Cuisine'),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  hint: AppStrings.description,
                  controller: _descriptionController,
                  required: true,
                  maxLines: 4,
                  validator: (String? value) => Validators.required(value, 'Description'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _isSubmitting ? null : _pickImage,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.attach_file, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        AppStrings.attachImage,
                        style: AppTextStyles.bodyMedium.copyWith(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_imageUrlController.text.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                    child: CachedNetworkImage(
                      imageUrl: ImageUtils.getImageUrl(_imageUrlController.text.trim()),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox(
                        height: 160,
                        child: Center(child: Text(AppStrings.previewUnavailable)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.paddingL),
                AppButton(
                  text: AppStrings.saveToDeck,
                  icon: Icons.add_circle,
                  onPressed: _submit,
                  isLoading: _isSubmitting,
                ),
                const SizedBox(height: AppDimensions.paddingXL),
                const Divider(color: AppColors.divider),
                const SizedBox(height: AppDimensions.paddingM),
                Text(
                  AppStrings.dishesYouAdded,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppDimensions.paddingM),
                if (_isLoadingMyDishes)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingL),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                else if (_myDishes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.paddingL),
                    child: Text(
                      AppStrings.noDishesAdded,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium,
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _myDishes.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Dish dish = _myDishes[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
                        child: _MyDishCard(dish: dish),
                      );
                    },
                  ),
                const SizedBox(height: AppDimensions.paddingL),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MyDishCard extends StatelessWidget {
  const _MyDishCard({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: AppColors.cardShadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(dish.title, style: AppTextStyles.cardTitle.copyWith(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    dish.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('15 ${AppStrings.minutes}', style: AppTextStyles.bodySmall),
                      const SizedBox(width: 16),
                      const Icon(Icons.people, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('2 ${AppStrings.servings}', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.paddingS),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              child: CachedNetworkImage(
                imageUrl: ImageUtils.getImageUrl(dish.imageUrl),
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const ColoredBox(
                  color: Colors.black12,
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
