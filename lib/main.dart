import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'model_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atık Türü Tanıma',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kamera hatası: $e')),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Galeri hatası: $e')),
        );
      }
    }
  }

  void _analyzeImage() {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce bir resim seçin')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultPage(imageFile: _selectedImage!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atık Türü Tanıma'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Atık Türünü Tanımla',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Kamera ile fotoğraf çekin veya galeriden seçin',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: _selectedImage == null
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_outlined,
                              size: 80,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Henüz resim seçilmedi',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImageFromCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Kamera'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImageFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Galeri'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _analyzeImage,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Analiz Et',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResultPage extends StatefulWidget {
  final File imageFile;

  const ResultPage({super.key, required this.imageFile});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  String _result = '';
  double _confidence = 0.0;
  bool _isLoading = true;
  Uint8List? _annotatedImageBytes;
  List<Map<String, dynamic>> _allDetections = [];
  final ModelService _modelService = ModelService();

  @override
  void initState() {
    super.initState();
    _runInference();
  }

  @override
  void dispose() {
    _modelService.dispose();
    super.dispose();
  }

  Future<void> _runInference() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Model ile tahmin yap
      var result = await _modelService.predict(widget.imageFile);

      setState(() {
        _result = result['label'] ?? 'Bilinmeyen';
        _confidence = result['confidence'] ?? 0.0;
        _allDetections = result['allDetections'] ?? [];
        
        // Bounding box'lı resmi PNG'ye çevir
        if (result['annotatedImage'] != null) {
          img.Image annotatedImage = result['annotatedImage'];
          _annotatedImageBytes = Uint8List.fromList(img.encodePng(annotatedImage));
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Hata oluştu: ${e.toString()}';
        _confidence = 0.0;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analiz Sonucu'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: _annotatedImageBytes != null
                      ? Image.memory(
                          _annotatedImageBytes!,
                          fit: BoxFit.contain,
                        )
                      : Image.file(
                          widget.imageFile,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
              const SizedBox(height: 30),
              if (_isLoading)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text(
                        'Analiz ediliyor...',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                )
              else
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 60,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Tespit Edilen Nesneler: ${_allDetections.length}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_allDetections.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Aynı nesnede farklı malzemeler tespit edildi',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 10),
                        // Tüm deteksiyonları listele
                        ..._allDetections.asMap().entries.map((entry) {
                          int index = entry.key;
                          var detection = entry.value;
                          
                          // Her malzeme tipi için farklı renk
                          List<Color> materialColors = [
                            Colors.green,
                            Colors.red,
                            Colors.blue,
                            Colors.orange,
                            Colors.purple,
                            Colors.teal,
                            Colors.pink,
                            Colors.indigo,
                            Colors.amber,
                          ];
                          
                          int classIdx = detection['classIndex'] ?? 0;
                          Color cardColor = materialColors[classIdx % materialColors.length];
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: cardColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: cardColor,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 45,
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        detection['label'] ?? 'Bilinmeyen',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: cardColor.withOpacity(0.9),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.analytics,
                                            size: 16,
                                            color: cardColor,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Güven: ${((detection['confidence'] ?? 0.0) * 100).toStringAsFixed(1)}%',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 70,
                                  child: Column(
                                    children: [
                                      CircularProgressIndicator(
                                        value: detection['confidence'] ?? 0.0,
                                        backgroundColor: Colors.grey[300],
                                        color: cardColor,
                                        strokeWidth: 6,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '${((detection['confidence'] ?? 0.0) * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: cardColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Yeni Analiz'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
