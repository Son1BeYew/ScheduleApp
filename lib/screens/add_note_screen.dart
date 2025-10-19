import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedule_app/generated/app_localizations.dart';
import 'package:schedule_app/config/api_config.dart';

class AddNoteScreen extends StatefulWidget {
  final String? groupId;

  const AddNoteScreen({super.key, this.groupId});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  XFile? _imageFile;
  bool _loading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _imageFile = pickedFile;
    });
  }

  Future<void> _createNote() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (token == null || title.isEmpty) {
      return;
    }

    setState(() => _loading = true);

    try {
      final noteUrl = Uri.parse(ApiConfig.apiNotes);
      
      final request = http.MultipartRequest('POST', noteUrl);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['title'] = title;
      request.fields['content'] = content;
      
      if (widget.groupId != null) {
        request.fields['groupId'] = widget.groupId!;
      }

      if (_imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('attachment', _imageFile!.path),
        );
      }

      final streamedResponse = await request.send();
      final noteResponse = await http.Response.fromStream(streamedResponse);

      if (noteResponse.statusCode == 201) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${AppLocalizations.of(context)!.apiError}${noteResponse.statusCode}")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${AppLocalizations.of(context)!.connectionError}$e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildAttachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachment',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (_imageFile != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_imageFile!.path),
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Change'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _imageFile = null),
                  icon: const Icon(Icons.close),
                  label: const Text('Remove'),
                ),
              ),
            ],
          ),
        ] else ...[
          OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.attach_file),
            label: const Text('Attach Image'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.newNote, style: GoogleFonts.poppins()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.title,
                hintText: AppLocalizations.of(context)!.title,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.content,
                hintText: AppLocalizations.of(context)!.content,
              ),
              maxLines: 8,
            ),
            const SizedBox(height: 24),
            _buildAttachmentSection(),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loading ? null : _createNote,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading 
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(AppLocalizations.of(context)!.create),
            ),
          ],
        ),
      ),
    );
  }
}