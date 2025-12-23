import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import 'dart:async';
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

  Future<void> _openLiveCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kamera bulunamadı')),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LiveCameraPage(camera: cameras.first),
        ),
      );
    }
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
              const SizedBox(height: 15),
              ElevatedButton.icon(
                onPressed: _openLiveCamera,
                icon: const Icon(Icons.videocam),
                label: const Text('Canlı Kamera'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
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

class LiveCameraPage extends StatefulWidget {
  final CameraDescription camera;

  const LiveCameraPage({super.key, required this.camera});

  @override
  State<LiveCameraPage> createState() => _LiveCameraPageState();
}

class _LiveCameraPageState extends State<LiveCameraPage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final ModelService _modelService = ModelService();
  
  Timer? _detectionTimer;
  String _currentLabel = '';
  double _currentConfidence = 0.0;
  List<Map<String, dynamic>> _detections = [];
  bool _isProcessing = false;
  
  // İstatistikler
  int _totalFrames = 0;
  int _detectedFrames = 0;
  
  // Kamera ve görüntü boyutları (bounding box dönüşümü için)
  Size? _imageSize;
  
  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller.initialize();
    
    // Her 1 saniyede bir frame'i analiz et
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _analyzeFrame();
    });
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _controller.dispose();
    _modelService.dispose();
    super.dispose();
  }

  Future<void> _analyzeFrame() async {
    if (_isProcessing || !_controller.value.isInitialized) {
      return;
    }

    _isProcessing = true;
    _totalFrames++;

    try {
      final image = await _controller.takePicture();
      final imageBytes = await image.readAsBytes();

      if (mounted) {
        final result = await _modelService.predictFromBytes(imageBytes);

        setState(() {
          _currentLabel = result['label'] ?? 'Bilinmeyen';
          _currentConfidence = result['confidence'] ?? 0.0;
          _detections = result['detections'] ?? [];
          
          // Görüntü boyutlarını kaydet
          if (result['imageWidth'] != null && result['imageHeight'] != null) {
            _imageSize = Size(
              result['imageWidth'].toDouble(),
              result['imageHeight'].toDouble(),
            );
          }
          
          if (_detections.isNotEmpty) {
            _detectedFrames++;
          }
        });
      }
    } catch (e) {
      print('Frame analiz hatası: $e');
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Canlı Nesne Tanıma'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Column(
              children: [
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_controller),
                            // Bounding box overlay
                            if (_detections.isNotEmpty && _imageSize != null)
                              CustomPaint(
                                painter: BoundingBoxPainter(
                                  detections: _detections,
                                  imageSize: _imageSize!,
                                  previewSize: Size(
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_isProcessing)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: SizedBox(
                                height: 20,
                                child: LinearProgressIndicator(),
                              ),
                            ),
                          const SizedBox(height: 10),
                          // Tespit edilen nesne kartı
                          if (_detections.isNotEmpty)
                            Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  children: [
                                    Text(
                                      'Tespit Edilen Nesneler: ${_detections.length}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ..._detections.take(3).map((detection) {
                                      List<Color> colors = [
                                        Colors.green,
                                        Colors.red,
                                        Colors.blue,
                                        Colors.orange,
                                        Colors.purple,
                                      ];
                                      int classIdx = detection['classIndex'] ?? 0;
                                      Color color = colors[classIdx % colors.length];

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: color,
                                              width: 2,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  detection['label'] ?? 'Bilinmeyen',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: color,
                                                    fontSize: 14,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                '${((detection['confidence'] ?? 0.0) * 100).toStringAsFixed(0)}%',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: color,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Nesne bekleniyor...',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          // İstatistik
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'İstatistik: $_totalFrames frame analiz, $_detectedFrames nesne tespit',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            label: const Text('Kapat'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }
}

/// Canlı kamera üzerinde bounding box çizmek için CustomPainter
class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Size imageSize;
  final Size previewSize;

  BoundingBoxPainter({
    required this.detections,
    required this.imageSize,
    required this.previewSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Her sınıf için farklı renk
    final List<Color> colors = [
      Colors.green,      // cam
      Colors.red,        // kagit
      Colors.blue,       // metal
      Colors.orange,     // pil
      Colors.purple,     // plastik
    ];

    for (var detection in detections) {
      if (detection['bbox'] == null) continue;

      var bbox = detection['bbox'];
      int classIdx = detection['classIndex'] ?? 0;
      Color boxColor = colors[classIdx % colors.length];

      // Koordinatları görüntü boyutundan önizleme boyutuna dönüştür
      double scaleX = previewSize.width / imageSize.width;
      double scaleY = previewSize.height / imageSize.height;

      double x1 = bbox['x1'] * scaleX;
      double y1 = bbox['y1'] * scaleY;
      double x2 = bbox['x2'] * scaleX;
      double y2 = bbox['y2'] * scaleY;

      // Bounding box çiz
      final boxPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      final rect = Rect.fromLTRB(x1, y1, x2, y2);
      canvas.drawRect(rect, boxPaint);

      // Etiket arka planı
      String label = '${detection['label']} ${((detection['confidence'] ?? 0.0) * 100).toStringAsFixed(0)}%';
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Etiket arka plan kutusu
      double labelY = y1 > 25 ? y1 - 22 : y1 + 5;
      final bgRect = Rect.fromLTWH(
        x1,
        labelY,
        textPainter.width + 8,
        textPainter.height + 4,
      );
      
      final bgPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.fill;
      
      canvas.drawRect(bgRect, bgPaint);

      // Etiketi çiz
      textPainter.paint(canvas, Offset(x1 + 4, labelY + 2));
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
