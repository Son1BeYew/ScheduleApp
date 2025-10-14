import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedule_app/generated/app_localizations.dart';

class EditNoteScreen extends StatefulWidget {
  final Map<String, dynamic>? note;

  const EditNoteScreen({super.key, this.note});

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  XFile? _imageFile;
  bool _isSaving = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.note!['title'] ?? '';
      _contentController.text = widget.note!['content'] ?? '';
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _imageFile = pickedFile;
    });
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception('Token not found');

      final url = _isEditing
          ? 'http://10.0.2.2:5000/api/notes/${widget.note!['_id']}'
          : 'http://10.0.2.2:5000/api/notes';
      
      final request = http.MultipartRequest(
        _isEditing ? 'PUT' : 'POST',
        Uri.parse(url),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['title'] = _titleController.text;
      request.fields['content'] = _contentController.text;

      if (_imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('attachment', _imageFile!.path));
      }

      final response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context, true); // Return true to signal success
      } else {
        throw Exception('Failed to save note: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? AppLocalizations.of(context)!.edit : AppLocalizations.of(context)!.newNote),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: Colors.white),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveNote,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.title),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.content),
              maxLines: 10,
            ),
            const SizedBox(height: 20),
            _buildAttachmentSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentSection() {
    String? existingAttachmentUrl;
    
    // Check attachments array (plural)
    if (_isEditing && widget.note!['attachments'] != null) {
      final attachments = widget.note!['attachments'] as List;
      if (attachments.isNotEmpty) {
        existingAttachmentUrl = 'http://10.0.2.2:5000${attachments[0]}';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attachment', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (_imageFile != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_imageFile!.path),
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          )
        else if (existingAttachmentUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              existingAttachmentUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 50),
                  ),
                );
              },
            ),
          )
        else
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No attachment', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (_imageFile != null || existingAttachmentUrl != null)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Change'),
                ),
              ),
              if (_imageFile != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _imageFile = null),
                    icon: const Icon(Icons.close),
                    label: const Text('Remove'),
                  ),
                ),
              ],
            ],
          )
        else
          ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.attach_file),
            label: const Text('Pick Image'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
      ],
    );
  }
}