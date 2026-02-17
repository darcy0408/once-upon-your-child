import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'models/generated_avatar.dart';
import 'services/avatar_generation_service.dart';
import 'avatar_models.dart';
import 'config/environment.dart';

class CustomAvatarScreen extends StatefulWidget {
  final String? initialName;
  final int? initialAge;

  const CustomAvatarScreen({
    super.key,
    this.initialName,
    this.initialAge,
  });

  @override
  State<CustomAvatarScreen> createState() => _CustomAvatarScreenState();
}

class _CustomAvatarScreenState extends State<CustomAvatarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  
  String _gender = 'girl';
  String _eyeColor = 'Brown';
  String _favoriteColor = 'Blue';
  
  File? _imageFile;
  bool _isGenerating = false;
  String? _generatedImagePath;
  
  final List<String> _eyeColors = ['Brown', 'Blue', 'Green', 'Hazel', 'Grey'];
  final List<String> _favoriteColors = [
    'Red', 'Blue', 'Green', 'Yellow', 'Purple', 'Pink', 'Orange', 'Teal', 'Gold'
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName ?? '';
    _ageController.text = widget.initialAge?.toString() ?? '7';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _generateAvatar() async {
    if (!_formKey.currentState!.validate() || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and take a photo!')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final baseUrl = Environment.backendUrl;
      final url = Uri.parse('$baseUrl/avatar/generate-custom-avatar');
      
      var request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('photo', _imageFile!.path));
      request.fields['character_name'] = _nameController.text;
      request.fields['age'] = _ageController.text;
      request.fields['gender'] = _gender;
      request.fields['eye_color'] = _eyeColor;
      request.fields['favorite_color'] = _favoriteColor;

      debugPrint('📡 Sending custom avatar request to $url');
      final streamedResponse = await request.send().timeout(const Duration(minutes: 3));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final avatarData = data['avatar'];
          final imageBase64 = avatarData['image_base64'] as String;
          
          // Save locally
          final localPath = await _saveImageLocally(imageBase64);
          
          setState(() {
            _generatedImagePath = localPath;
            _isGenerating = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Magical Avatar Created! ✨')),
          );
        } else {
          throw Exception(data['message'] ?? 'Generation failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error generating custom avatar: $e');
      setState(() {
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<String> _saveImageLocally(String base64String) async {
    final bytes = base64Decode(base64String.split(',').last);
    final directory = await getApplicationDocumentsDirectory();
    final avatarsDir = Directory(path.join(directory.path, 'custom_avatars'));
    if (!await avatarsDir.exists()) {
      await avatarsDir.create(recursive: true);
    }
    
    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(path.join(avatarsDir.path, fileName));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Magical Avatar Creator'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create a hero that looks like you!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // Photo Section
              GestureDetector(
                onTap: _isGenerating ? null : _takePhoto,
                child: Container(
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.indigo.withOpacity(0.3), width: 2),
                    image: _imageFile != null 
                        ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _imageFile == null 
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 60, color: Colors.indigo),
                            SizedBox(height: 10),
                            Text('Tap to snap a photo', style: TextStyle(color: Colors.indigo)),
                          ],
                        )
                      : null,
                ),
              ),
              if (_imageFile != null)
                TextButton.icon(
                  onPressed: _isGenerating ? null : _takePhoto,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake Photo'),
                ),
              
              const SizedBox(height: 20),
              
              // Inputs
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Hero Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 15),
              
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.cake),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.isEmpty) ? 'Enter age' : null,
              ),
              const SizedBox(height: 15),
              
              Row(
                children: [
                  const Text('Gender: ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'girl', label: Text('Girl'), icon: Icon(Icons.female)),
                        ButtonSegment(value: 'boy', label: Text('Boy'), icon: Icon(Icons.male)),
                      ],
                      selected: {_gender},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _gender = newSelection.first;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              
              DropdownButtonFormField<String>(
                value: _eyeColor,
                decoration: const InputDecoration(
                  labelText: 'Eye Color',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.visibility),
                ),
                items: _eyeColors.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => _eyeColor = val!),
              ),
              const SizedBox(height: 15),
              
              DropdownButtonFormField<String>(
                value: _favoriteColor,
                decoration: const InputDecoration(
                  labelText: 'Favorite Color',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.favorite),
                ),
                items: _favoriteColors.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => _favoriteColor = val!),
              ),
              
              const SizedBox(height: 30),
              
              if (_isGenerating)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Brewing your magical avatar...', style: TextStyle(fontStyle: FontStyle.italic)),
                    Text('(This takes about a minute)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                )
              else if (_generatedImagePath != null)
                Column(
                  children: [
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                        image: DecorationImage(image: FileImage(File(_generatedImagePath!)), fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Return the custom avatar data
                        final customAvatar = CharacterAvatar.defaultAvatar.copyWith(
                          customImagePath: _generatedImagePath,
                          isCustom: true,
                        );
                        Navigator.pop(context, customAvatar);
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Use This Avatar!'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                      ),
                    ),
                  ],
                )
              else
                ElevatedButton(
                  onPressed: _generate_avatar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Generate Magic Avatar ✨', style: TextStyle(fontSize: 18)),
                ),
                
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
