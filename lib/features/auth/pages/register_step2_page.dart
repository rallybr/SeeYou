import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

typedef OnNextStep2 = void Function(Map<String, dynamic> profileData);

typedef OnBackStep = void Function();

class RegisterStep2Page extends StatefulWidget {
  final OnNextStep2 onNext;
  final OnBackStep onBack;
  const RegisterStep2Page({Key? key, required this.onNext, required this.onBack}) : super(key: key);

  @override
  State<RegisterStep2Page> createState() => _RegisterStep2PageState();
}

class _RegisterStep2PageState extends State<RegisterStep2Page> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();
  DateTime? _selectedDate;
  int? _selectedEstadoId;
  List<Map<String, dynamic>> _estados = [];
  bool _loading = false;
  bool _loadingEstados = true;
  File? _avatarImage;
  String? _avatarUrl;
  final ImagePicker _picker = ImagePicker();
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _fetchEstados();
  }

  Future<void> _fetchEstados() async {
    final response = await Supabase.instance.client.from('estados').select('id, nome').order('nome');
    setState(() {
      _estados = List<Map<String, dynamic>>.from(response);
      _loadingEstados = false;
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecionar foto'),
        content: const Text('Escolha a origem da foto de perfil:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Câmera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Galeria'),
          ),
        ],
      ),
    );
    if (source == null) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _avatarImage = File(picked.path);
        _uploadingAvatar = true;
      });
      await _uploadAvatar(File(picked.path));
      setState(() {
        _uploadingAvatar = false;
      });
    }
  }

  void _updateAvatarUrlOnParent(String? url) {
    widget.onNext({
      'avatar_url': url,
    });
  }

  Future<void> _uploadAvatar(File file) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final fileExt = path.extension(file.path);
    final fileName = 'avatar_$userId$fileExt';
    final storage = Supabase.instance.client.storage;
    final bucket = storage.from('avatar');
    try {
      final res = await bucket.upload(
        fileName,
        file,
        fileOptions: const FileOptions(upsert: true),
      );
      if (res != null && res is String) {
        final url = bucket.getPublicUrl(fileName);
        setState(() {
          _avatarUrl = url;
        });
      } else {
        _showUploadError();
      }
    } catch (e) {
      _showUploadError();
    } finally {
      setState(() {
        _uploadingAvatar = false;
      });
    }
  }

  void _showUploadError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Erro ao fazer upload da foto. Tente novamente.')),
    );
  }

  void _handleNext() {
    setState(() => _loading = true);
    widget.onNext({
      'full_name': _fullNameController.text,
      'username': _usernameController.text,
      'bio': _bioController.text,
      'website': _websiteController.text,
      'estado_id': _selectedEstadoId,
      'data_nasc': _selectedDate != null ? _selectedDate!.toIso8601String().split('T').first : null,
      'avatar_url': _avatarUrl,
    });
    setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Step 2: Perfil', style: TextStyle(fontSize: 20, color: Colors.green)),
            GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: _avatarImage != null
                        ? FileImage(_avatarImage!)
                        : (_avatarUrl != null ? NetworkImage(_avatarUrl!) : null) as ImageProvider?,
                    child: _avatarImage == null && _avatarUrl == null
                        ? const Icon(Icons.camera_alt, size: 40, color: Colors.white)
                        : null,
                    backgroundColor: Colors.grey[300],
                  ),
                  if (_uploadingAvatar)
                    const CircularProgressIndicator(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(labelText: 'Nome completo'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(labelText: 'Bio'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _websiteController,
              decoration: const InputDecoration(labelText: 'Website (opcional)'),
            ),
            const SizedBox(height: 16),
            _loadingEstados
                ? const CircularProgressIndicator()
                : DropdownButtonFormField<int>(
                    value: _selectedEstadoId,
                    items: _estados
                        .map((estado) => DropdownMenuItem<int>(
                              value: estado['id'] as int,
                              child: Text(estado['nome'] as String),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedEstadoId = value;
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Estado'),
                  ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Data de nascimento'),
                child: Text(_selectedDate != null
                    ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
                    : 'Selecione a data'),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : widget.onBack,
                    child: const Text('Voltar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading || _uploadingAvatar || (_avatarImage != null && _avatarUrl == null)
                      ? null
                      : _handleNext,
                    child: _loading || _uploadingAvatar
                      ? const CircularProgressIndicator()
                      : const Text('Próximo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 