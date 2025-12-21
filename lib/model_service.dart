import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class ModelService {
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isModelLoaded = false;

  static const int inputSize = 512;
  static const int numClasses = 5;
  static const double confidenceThreshold = 0.25;
  static const double iouThreshold = 0.45;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/best.tflite');
      
      print('Input shape: ${_interpreter!.getInputTensors()}');
      print('Output shape: ${_interpreter!.getOutputTensors()}');
      
      try {
        final labelsData = await rootBundle.loadString('assets/labels.txt');
        _labels = labelsData.split('\n').where((line) => line.trim().isNotEmpty).toList();
        print('${_labels!.length} etiket yüklendi');
      } catch (e) {
        print('Labels dosyası yüklenemedi: $e');
        _labels = [];
      }

      _isModelLoaded = true;
      print('Model başarıyla yüklendi');
    } catch (e) {
      print('Model yükleme hatası: $e');
      _isModelLoaded = false;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> predict(File imageFile) async {
    if (!_isModelLoaded || _interpreter == null) {
      await loadModel();
    }

    if (_interpreter == null) {
      throw Exception('Model yüklenemedi');
    }

    try {
      final imageBytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);
      
      if (originalImage == null) {
        throw Exception('Resim decode edilemedi');
      }

      img.Image resizedImage = img.copyResize(
        originalImage,
        width: inputSize,
        height: inputSize,
      );

      var input = _imageToByteListFloat32(resizedImage);
      
      var inputShape = _interpreter!.getInputTensor(0).shape;
      print('Input tensor shape: $inputShape');
      
      var inputTensor = input.reshape([1, inputSize, inputSize, 3]);

      var outputShape = _interpreter!.getOutputTensor(0).shape;
      print('Output tensor shape: $outputShape');

      var output = List.generate(
        outputShape[1],
        (i) => List.filled(outputShape[2], 0.0),
      ).reshape([1, outputShape[1], outputShape[2]]);

      _interpreter!.run(inputTensor, output);
      
      print('Output sample: ${output[0][0].sublist(0, 10)}');

      var detections = _processOutput(output, originalImage);
      
      detections = _applyNMS(detections);

      if (detections.isEmpty) {
        return {
          'label': 'Nesne tespit edilemedi',
          'confidence': 0.0,
          'annotatedImage': originalImage,
        };
      }

      detections.sort((a, b) => b['confidence'].compareTo(a['confidence']));
      
      img.Image annotatedImage = _drawDetections(originalImage, detections);
      
      var result = detections.first;
      result['annotatedImage'] = annotatedImage;
      result['allDetections'] = detections;
      
      return result;
    } catch (e, stackTrace) {
      print('Tahmin hatası: $e');
      print('Stack trace: $stackTrace');
      return {
        'label': 'Hata: $e',
        'confidence': 0.0,
      };
    }
  }

  List<Map<String, dynamic>> _processOutput(List<dynamic> output, img.Image originalImage) {
    List<Map<String, dynamic>> detections = [];

    try {
      var batch = output[0];
      
      int numFeatures = batch.length;
      int numPredictions = batch[0].length;
      
      print('Processing output: $numFeatures features x $numPredictions predictions');
      
      int numCoords = 4;
      int numClasses = numFeatures - numCoords;
      
      List<double> classMaxScores = List.filled(numClasses, 0.0);
      
      for (var i = 0; i < numPredictions; i++) {
        double centerX = batch[0][i].toDouble();
        double centerY = batch[1][i].toDouble();
        double width = batch[2][i].toDouble();
        double height = batch[3][i].toDouble();
        
        double maxClassScore = 0.0;
        int maxClassIdx = 0;
        
        for (var j = 0; j < numClasses; j++) {
          double classScore = batch[numCoords + j][i].toDouble();
          
          if (classScore > classMaxScores[j]) {
            classMaxScores[j] = classScore;
          }
          
          if (classScore > maxClassScore) {
            maxClassScore = classScore;
            maxClassIdx = j;
          }
        }
        
        if (maxClassScore < confidenceThreshold) continue;
        
        if (width < 0.05 || height < 0.05) continue;
        
        double x1 = (centerX - width / 2) * originalImage.width;
        double y1 = (centerY - height / 2) * originalImage.height;
        double x2 = (centerX + width / 2) * originalImage.width;
        double y2 = (centerY + height / 2) * originalImage.height;
        
        x1 = x1.clamp(0.0, originalImage.width.toDouble());
        y1 = y1.clamp(0.0, originalImage.height.toDouble());
        x2 = x2.clamp(0.0, originalImage.width.toDouble());
        y2 = y2.clamp(0.0, originalImage.height.toDouble());
        
        String label = _labels != null && maxClassIdx < _labels!.length
            ? _labels![maxClassIdx].trim()
            : 'Class $maxClassIdx';

        detections.add({
          'label': label,
          'confidence': maxClassScore,
          'classIndex': maxClassIdx,
          'bbox': {'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2},
        });
      }
      
      print('\n=== SINIF BAZLI MAX SCORE\'LAR ===');
      for (var i = 0; i < numClasses; i++) {
        String className = _labels != null && i < _labels!.length ? _labels![i] : 'Class $i';
        print('$className: ${(classMaxScores[i] * 100).toStringAsFixed(2)}%');
      }
      
      print('\n=== TESPİT EDİLEN NESNELER (NMS öncesi) ===');
      print('${detections.length} nesne');
    } catch (e, stackTrace) {
      print('Output işleme hatası: $e');
      print('Stack trace: $stackTrace');
    }

    return detections;
  }
  
  List<Map<String, dynamic>> _applyNMS(List<Map<String, dynamic>> detections) {
    if (detections.isEmpty) return detections;
    
    detections.sort((a, b) => b['confidence'].compareTo(a['confidence']));
    
    List<Map<String, dynamic>> filtered = [];
    List<bool> suppressed = List.filled(detections.length, false);
    
    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      
      filtered.add(detections[i]);
      var boxA = detections[i]['bbox'];
      
      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        
        var boxB = detections[j]['bbox'];
        double iou = _calculateIoU(boxA, boxB);
        
        if (iou > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }
    
    print('NMS sonrası: ${filtered.length} nesne (${detections.length - filtered.length} çakışan box kaldırıldı)');
    
    for (var i = 0; i < filtered.length; i++) {
      print('${i + 1}. ${filtered[i]['label']} - ${(filtered[i]['confidence'] * 100).toStringAsFixed(2)}%');
    }
    
    return filtered;
  }
  
  double _calculateIoU(Map<String, dynamic> boxA, Map<String, dynamic> boxB) {
    double x1A = boxA['x1'];
    double y1A = boxA['y1'];
    double x2A = boxA['x2'];
    double y2A = boxA['y2'];
    
    double x1B = boxB['x1'];
    double y1B = boxB['y1'];
    double x2B = boxB['x2'];
    double y2B = boxB['y2'];
    
    double xLeft = x1A > x1B ? x1A : x1B;
    double yTop = y1A > y1B ? y1A : y1B;
    double xRight = x2A < x2B ? x2A : x2B;
    double yBottom = y2A < y2B ? y2A : y2B;
    
    if (xRight < xLeft || yBottom < yTop) {
      return 0.0;
    }
    
    double intersectionArea = (xRight - xLeft) * (yBottom - yTop);
    
    double boxAArea = (x2A - x1A) * (y2A - y1A);
    double boxBArea = (x2B - x1B) * (y2B - y1B);
    
    double unionArea = boxAArea + boxBArea - intersectionArea;
    
    return intersectionArea / unionArea;
  }
  
  img.Image _drawDetections(img.Image image, List<Map<String, dynamic>> detections) {
    img.Image annotated = img.Image.from(image);
    
    List<img.Color> colors = [
      img.ColorRgb8(0, 255, 0),
      img.ColorRgb8(255, 0, 0),
      img.ColorRgb8(0, 0, 255),
      img.ColorRgb8(255, 255, 0),
      img.ColorRgb8(255, 0, 255),
    ];
    
    for (var i = 0; i < detections.length; i++) {
      var detection = detections[i];
      if (detection['bbox'] == null) continue;
      
      var bbox = detection['bbox'];
      int x1 = bbox['x1'].clamp(0, image.width - 1).toInt();
      int y1 = bbox['y1'].clamp(0, image.height - 1).toInt();
      int x2 = bbox['x2'].clamp(0, image.width - 1).toInt();
      int y2 = bbox['y2'].clamp(0, image.height - 1).toInt();
      
      int classIdx = detection['classIndex'] ?? 0;
      img.Color boxColor = colors[classIdx % colors.length];
      
      img.drawRect(
        annotated,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        color: boxColor,
        thickness: 4,
      );
      
      String text = '${i + 1}. ${detection['label']} ${(detection['confidence'] * 100).toStringAsFixed(0)}%';
      
      int textY = y1 > 35 ? y1 - 30 : y1 + 5;
      img.fillRect(
        annotated,
        x1: x1,
        y1: textY,
        x2: (x1 + text.length * 12).clamp(0, image.width),
        y2: textY + 25,
        color: boxColor,
      );
      
      img.drawString(
        annotated,
        text,
        font: img.arial24,
        x: x1 + 5,
        y: textY + 3,
        color: img.ColorRgb8(255, 255, 255),
      );
    }
    
    print('${detections.length} nesne için bounding box çizildi');
    return annotated;
  }

  Float32List _imageToByteListFloat32(img.Image image) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        
        buffer[pixelIndex++] = pixel.r / 255.0;
        buffer[pixelIndex++] = pixel.g / 255.0;
        buffer[pixelIndex++] = pixel.b / 255.0;
      }
    }

    return convertedBytes;
  }

  void dispose() {
    _interpreter?.close();
    _isModelLoaded = false;
  }
}