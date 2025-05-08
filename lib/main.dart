import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const SalahPostureApp());
}

class SalahPostureApp extends StatelessWidget {
  const SalahPostureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Salah Posture Classifier',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  Interpreter? _interpreter;
  String _result = '';

  final List<String> labels = ['Standing', 'Bowing', 'Prostrating', 'Sitting'];

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/prayer_posture_model.tflite',
      );
      print('✅ Model loaded successfully');
    } catch (e) {
      print('❌ Failed to load model: $e');
    }
  }

  Future<List<List<List<List<double>>>>?> preprocessImage(
    File imageFile,
  ) async {
    try {
      final rawBytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return null;

      final resized = img.copyResize(decoded, width: 224, height: 224);

      return [
        List.generate(224, (y) {
          return List.generate(224, (x) {
            final pixel = resized.getPixel(x, y);
            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          });
        }),
      ];
    } catch (e) {
      print('❌ Image preprocessing failed: $e');
      return null;
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        setState(() {
          _image = file;
          _result = '';
        });

        print('📸 Image selected: ${file.path}');
        final input = await preprocessImage(file);
        if (input == null) {
          print('❌ Failed to preprocess image.');
          return;
        }

        if (_interpreter == null) {
          print('❌ Interpreter not loaded.');
          return;
        }

        var output = List.filled(4, 0.0).reshape([1, 4]);

        print('🚀 Running inference...');
        _interpreter!.run(input, output);
        print('✅ Output: $output');

        final List<double> probs = List<double>.from(output[0]);
        final predictedIndex = probs.indexOf(
          probs.reduce((a, b) => a > b ? a : b),
        );

        final label = labels[predictedIndex];
        final confidence = (probs[predictedIndex] * 100).toStringAsFixed(2);

        final formattedResult = '🧎 $label\nConfidence: $confidence%';

        print('🎯 Result: $formattedResult');

        if (mounted) {
          setState(() {
            _result = formattedResult;
          });
        }
      } else {
        print('⚠️ No image selected.');
      }
    } catch (e) {
      print('❌ Unexpected error during classification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Salah Posture Classifier')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _image != null
                  ? Image.file(_image!, height: 300)
                  : const Text('No image selected.'),
              const SizedBox(height: 20),
              Text(
                _result,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo),
                label: const Text("Pick from Gallery"),
              ),
              ElevatedButton.icon(
                onPressed: () => pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera),
                label: const Text("Take a Picture"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
