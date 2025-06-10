import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({Key? key}) : super(key: key);

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final List<File> _selectedImages = [];
  final TextEditingController _captionController = TextEditingController();
  bool _isLoading = false;

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((image) => File(image.path)));
      });
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    
    if (photo != null) {
      setState(() {
        _selectedImages.add(File(photo.path));
      });
    }
  }

  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escolher fonte da imagem'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria'),
              onTap: () {
                Navigator.pop(context);
                _pickImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publishPost() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos uma imagem')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Upload das imagens para o Supabase Storage
      final List<String> imageUrls = [];
      for (var image in _selectedImages) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}';
        final response = await Supabase.instance.client.storage
            .from('posts')
            .upload(fileName, image);
        
        final imageUrl = Supabase.instance.client.storage
            .from('posts')
            .getPublicUrl(fileName);
        
        imageUrls.add(imageUrl);
      }

      // Criar o post no banco de dados
      await Supabase.instance.client.from('posts').insert({
        'user_id': user.id,
        'content_text': _captionController.text,
        'media_urls': imageUrls,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post publicado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao publicar post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6A85F1), // azul
                Color(0xFFFBC2EB), // rosa claro
                Color(0xFFF9F586), // amarelo claro
                Color(0xFFF68084), // rosa
              ],
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Nova publicação'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_selectedImages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _publishPost,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 6,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.black26,
                    ).copyWith(
                      backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                        return null;
                      }),
                      foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF2D2EFF),
                            Color(0xFF7B2FF2),
                            Color(0xFFE94057),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 80, minHeight: 36),
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Publicar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
            ],
            backgroundColor: Colors.black.withOpacity(0.4),
            elevation: 0,
            titleTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (_selectedImages.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_photo_alternate, size: 80, color: Colors.grey),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _showImageSourceDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Selecionar fotos'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.85),
                              foregroundColor: Colors.black87,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedImages.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _selectedImages.length) {
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: InkWell(
                                    onTap: _showImageSourceDialog,
                                    child: Container(
                                      width: 150,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      child: const Icon(Icons.add_photo_alternate, size: 50),
                                    ),
                                  ),
                                );
                              }
                              return Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _selectedImages[index],
                                        width: 150,
                                        height: 200,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white),
                                      onPressed: () {
                                        setState(() {
                                          _selectedImages.removeAt(index);
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: TextField(
                            controller: _captionController,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              hintText: 'Escreva uma legenda...',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }
} 