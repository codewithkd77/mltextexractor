import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();  //correct this line from the pavan repository
  runApp(TextRecognitionApp(cameras: cameras));
}

class TextRecognitionApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const TextRecognitionApp({required this.cameras, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Text Recognition',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueAccent,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      home: TextRecognitionHome(cameras: cameras),
    );
  }
}

class TextRecognitionHome extends StatefulWidget {
  final List<CameraDescription> cameras;

  const TextRecognitionHome({required this.cameras, Key? key}) : super(key: key);

  @override
  _TextRecognitionHomeState createState() => _TextRecognitionHomeState();
}

class _TextRecognitionHomeState extends State<TextRecognitionHome> {
  String recognizedText = '';
  bool isLoading = false;
  List<String> copiedTexts = [];
  int currentIndex = 0;
  File? currentImage;

  @override
  void initState() {
    super.initState();
    loadCopiedTexts();
  }

  Future<void> loadCopiedTexts() async {
    final prefs = await SharedPreferences.getInstance();
    final copiedTextsJson = prefs.getString('copiedTexts');
    if (copiedTextsJson != null) {
      setState(() {
        copiedTexts = List<String>.from(json.decode(copiedTextsJson));
      });
    }
  }

  Future<void> saveCopiedTexts() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('copiedTexts', json.encode(copiedTexts));
  }

  Future<void> requestPermissions() async {
    var cameraStatus = await Permission.camera.request();
    var storageStatus = await Permission.storage.request();
    if (cameraStatus.isDenied || storageStatus.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please grant camera and storage permissions')),
      );
    }
  }

  Future<File?> cropImage(File imageFile) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.blueAccent,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop Image',
        ),
      ],
    );

    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<void> pickImageFromGallery() async {
    await requestPermissions();
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      File? croppedImage = await cropImage(File(pickedFile.path));
      if (croppedImage != null) {
        setState(() {
          currentImage = croppedImage;
        });
        processImage(croppedImage);
      }
    }
  }

  Future<void> processImage(File imageFile) async {
    setState(() {
      isLoading = true;
    });
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer();
    final RecognizedText result = await textRecognizer.processImage(inputImage);
    setState(() {
      recognizedText = result.text;
      isLoading = false;
    });
    textRecognizer.close();
  }

  void copyToClipboard() {
    if (recognizedText.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: recognizedText)).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard! You can also check in copied text section')),
        );
        setState(() {
          copiedTexts.insert(0, recognizedText);
          saveCopiedTexts(); // Save to persistent storage
        });
      });
    }
  }

  // New method to export text as PDF
  Future<void> exportAsPDF() async {
    if (recognizedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text to export')),
      );
      return;
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Center(
          child: pw.Text(recognizedText, style: pw.TextStyle(fontSize: 16)),
        ),
      ),
    );

    try {
      final directory = await getExternalStorageDirectory();
      final file = File('${directory?.path}/recognized_text.pdf');
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved to ${file.path}')),
      );

      // Option to share the PDF
      _showShareDialog(file);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving PDF: $e')),
      );
    }
  }

  // New method to export text as a text file
  Future<void> exportAsTextFile() async {
    if (recognizedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text to export')),
      );
      return;
    }

    try {
      final directory = await getExternalStorageDirectory();
      final file = File('${directory?.path}/recognized_text.txt');
      await file.writeAsString(recognizedText);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Text file saved to ${file.path}')),
      );

      // Option to share the text file
      _showShareDialog(file);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving text file: $e')),
      );
    }
  }

  // New method to show share dialog
  void _showShareDialog(File file) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Export Successful'),
          content: const Text('Would you like to share the file?'),
          actions: [
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Share'),
              onPressed: () {
                Navigator.of(context).pop();
                _shareFile(file);
              },
            ),
          ],
        );
      },
    );
  }

  // New method to share file
  void _shareFile(File file) {
    Share.shareXFiles([XFile(file.path)], text: 'Check out the extracted text');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Text Extractor',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: currentIndex == 0 ? buildTextRecognitionView() : buildCopiedTextsView(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.text_fields), label: 'Text Recognition'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Copied Texts'),
        ],
      ),
    );
  }

  Widget buildTextRecognitionView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: pickImageFromGallery,
            icon: const Icon(Icons.image),
            label: const Text('Pick Image'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              final imageFile = await Navigator.push(context, MaterialPageRoute(builder: (context) => CameraScreen(cameras: widget.cameras)));
              if (imageFile != null) {
                bool? shouldCrop = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                          title: const Text("Confirm"),
                          content: Column(mainAxisSize: MainAxisSize.min, children: [
                            Image.file(imageFile),
                            const SizedBox(height: 10),
                            const Text("Would you like to crop this image?")
                          ]),
                          actions: <Widget>[
                            TextButton(
                                child: const Text("Crop"),
                                onPressed: () { Navigator.of(context).pop(true); }
                            ),
                            TextButton(
                                child: const Text("Ok"),
                                onPressed: () { Navigator.of(context).pop(false); }
                            ),
                            TextButton(
                                child: const Text("Retake"),
                                onPressed: () { Navigator.of(context).pop(null); }
                            )
                          ]
                      );
                    }
                );

                if (shouldCrop != null) {
                  if (shouldCrop) {
                    File? croppedImage = await cropImage(imageFile);
                    if (croppedImage != null) {
                      setState(() {
                        currentImage = croppedImage;
                      });
                      processImage(croppedImage);
                    }
                  } else {
                    setState(() {
                      currentImage = imageFile;
                    });
                    processImage(imageFile);
                  }
                }
              }
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Picture'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
          const SizedBox(height: 20),
          if (currentImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Image.file(
                currentImage!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        SelectableText(
                            recognizedText.isEmpty ? 'No text recognized' : recognizedText,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center
                        )
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: copyToClipboard,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Copy to Clipboard'),
                ),
              ),
              const SizedBox(width: 10),
              PopupMenuButton<String>(
                onSelected: (String choice) {
                  switch (choice) {
                    case 'PDF':
                      exportAsPDF();
                      break;
                    case 'Text File':
                      exportAsTextFile();
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'PDF',
                    child: Text('Export as PDF'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'Text File',
                    child: Text('Export as Text File'),
                  ),
                ],
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildCopiedTextsView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.separated(
        itemCount: copiedTexts.length,
        separatorBuilder: (context, index) => const Divider(height: 20),
        itemBuilder: (context, index) => Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            title: SelectableText(copiedTexts[index]),
          ),
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({required this.cameras, Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController controller;
  late Future<void> initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    controller = CameraController(widget.cameras.first, ResolutionPreset.high);
    initializeControllerFuture = controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> takePicture() async {
    try {
      await initializeControllerFuture;
      final imageFile = await controller.takePicture();
      Navigator.pop(context, File(imageFile.path));
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Camera")),
        body: FutureBuilder<void>(
            future: initializeControllerFuture,
            builder: (context, snapshot) =>
            snapshot.connectionState == ConnectionState.done ?
            Stack(
                children: [
                  CameraPreview(controller),
                  Positioned.fill(
                      child: Align(
                          alignment: Alignment.bottomCenter,
                          child: ElevatedButton.icon(
                              onPressed: takePicture,
                              icon: const Icon(Icons.camera),
                              label: const Text("Capture"),
                              style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(150, 50)
                              )
                          )
                      )
                  )
                ]
            ) :
            const Center(child: CircularProgressIndicator())
        )
    );
  }
}
