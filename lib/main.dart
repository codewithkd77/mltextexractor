import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'package:flutter/services.dart';

void main() => runApp(TextRecognitionApp());

class TextRecognitionApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Text Recognition',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: TextRecognitionHome(),
    );
  }
}

class TextRecognitionHome extends StatefulWidget {
  @override
  _TextRecognitionHomeState createState() => _TextRecognitionHomeState();
}

class _TextRecognitionHomeState extends State<TextRecognitionHome> {
  String recognizedText = '';
  bool isLoading = false;

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.getImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      processImage(File(pickedFile.path));
    }
  }

  Future<void> processImage(File imageFile) async {
    setState(() {
      isLoading = true; // Show loading indicator
    });

    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer();

    final RecognizedText result = await textRecognizer.processImage(inputImage);

    setState(() {
      recognizedText = result.text;
      isLoading = false; // Hide loading indicator
    });

    textRecognizer.close();
  }

  void copyToClipboard() {
    if (recognizedText.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: recognizedText)).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copied to clipboard!')),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Text Recognition'),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              // Show information dialog or navigate to another page
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('About'),
                  content: Text('This app recognizes text from images.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: pickImage,
              icon: Icon(Icons.image),
              label: Text('Pick Image'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50), // Full width button
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        if (isLoading)
                          Center(child: CircularProgressIndicator())
                        else
                          SelectableText(
                            recognizedText.isEmpty ? 'No text recognized' : recognizedText,
                            style: TextStyle(fontSize: 16),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: copyToClipboard,
              child: Text('Copy to Clipboard'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50), // Full width button
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}