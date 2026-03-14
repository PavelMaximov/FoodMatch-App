import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/dish_repository.dart';
import '../../../../data/repositories/upload_repository.dart';

class AddDishScreen extends StatefulWidget {
  const AddDishScreen({super.key});

  @override
  State<AddDishScreen> createState() => _AddDishScreenState();
}

class _AddDishScreenState extends State<AddDishScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cuisineController = TextEditingController();
  final _tagsController = TextEditingController();
  final _imageUrlController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _cuisineController.dispose();
    _tagsController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final uploadRepository = context.read<UploadRepository>();
      final url = await uploadRepository.uploadImage(File(image.path));
      _imageUrlController.text = url;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить изображение')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final dishRepository = context.read<DishRepository>();
      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await dishRepository.createDish(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        cuisine: _cuisineController.text.trim().isEmpty ? 'Other' : _cuisineController.text.trim(),
        tags: tags,
      );

      _formKey.currentState!.reset();
      _titleController.clear();
      _descriptionController.clear();
      _cuisineController.clear();
      _tagsController.clear();
      _imageUrlController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Блюдо добавлено!')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка при добавлении блюда')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить блюдо')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Название'),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Обязательное поле' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Описание'),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Обязательное поле' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cuisineController,
                  decoration: const InputDecoration(labelText: 'Кухня'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(labelText: 'Теги (через запятую)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(labelText: 'URL изображения'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _pickImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Выбрать фото'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Добавить блюдо'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
