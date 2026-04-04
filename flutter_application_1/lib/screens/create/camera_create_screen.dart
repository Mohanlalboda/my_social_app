// ignore_for_file: use_build_context_synchronously

import 'upload_media_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

class CameraCreateScreen extends StatefulWidget {
  const CameraCreateScreen({super.key});

  @override
  State<CameraCreateScreen> createState() => _CameraCreateScreenState();
}

class _CameraCreateScreenState extends State<CameraCreateScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isRecording = false;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  // 🌟 కెమెరా స్టార్ట్ చేయడం
  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _setCamera(_selectedCameraIndex);
    }
  }

  Future<void> _setCamera(int index) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      _cameras![index],
      ResolutionPreset.high, // క్వాలిటీ సెట్టింగ్
      enableAudio: true,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // 🔄 ఫ్రంట్ / బ్యాక్ కెమెరా మార్చడం
  void _switchCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIndex = _selectedCameraIndex == 0 ? 1 : 0;
    _setCamera(_selectedCameraIndex);
  }

  // ⚡ ఫ్లాష్ ఆన్/ఆఫ్
  void _toggleFlash() async {
    if (_cameraController == null) return;
    _isFlashOn = !_isFlashOn;
    await _cameraController!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
    setState(() {});
  }

  // 📸 ఫోటో తీయడం
  Future<void> _takePhoto() async {
    if (!_cameraController!.value.isInitialized || _isRecording) return;
    try {
      XFile file = await _cameraController!.takePicture();
      _goToPreview(file.path, false);
    } catch (e) {
      debugPrint("Take Photo Error: $e");
    }
  }

  // 🎥 వీడియో రికార్డింగ్ స్టార్ట్
  Future<void> _startVideo() async {
    if (!_cameraController!.value.isInitialized || _isRecording) return;
    try {
      await _cameraController!.startVideoRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint("Start Video Error: $e");
    }
  }

  // 🛑 వీడియో రికార్డింగ్ స్టాప్
  Future<void> _stopVideo() async {
    if (!_cameraController!.value.isRecordingVideo) return;
    try {
      XFile file = await _cameraController!.stopVideoRecording();
      setState(() => _isRecording = false);
      _goToPreview(file.path, true);
    } catch (e) {
      debugPrint("Stop Video Error: $e");
    }
  }

  // 🖼️ గ్యాలరీ నుండి సెలెక్ట్ చేయడం
  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final XFile? file = await picker
        .pickMedia(); // ఫోటో లేదా వీడియో ఏదైనా అలో చేస్తుంది
    if (file != null) {
      // వీడియోనా కాదా అని చెక్ చేయడం (చివర mp4 ఉంటే వీడియో)
      bool isVideo = file.path.toLowerCase().endsWith('.mp4');
      _goToPreview(file.path, isVideo);
    }
  }

  // ➡️ నెక్స్ట్ పేజీకి వెళ్లడం (Preview / Upload)
  void _goToPreview(String path, bool isVideo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UploadMediaScreen(filePath: path, isVideo: isVideo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🌟 1. కెమెరా లైవ్ ప్రివ్యూ
          CameraPreview(_cameraController!),

          // 🌟 2. పైన కంట్రోల్స్ (Flash, Close)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                IconButton(
                  icon: Icon(
                    _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: _isFlashOn ? Colors.yellow : Colors.white,
                    size: 30,
                  ),
                  onPressed: _toggleFlash,
                ),
              ],
            ),
          ),

          // 🌟 3. కింద బటన్స్ (Gallery, Record/Capture, Switch)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // గ్యాలరీ బటన్
                GestureDetector(
                  onTap: _pickFromGallery,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.photo_library, color: Colors.white),
                  ),
                ),

                // 📸 రికార్డ్ బటన్ (Tap: Photo, LongPress: Video)
                GestureDetector(
                  onTap: _takePhoto, // సింగిల్ ట్యాప్
                  onLongPress: _startVideo, // నొక్కి పడితే
                  onLongPressUp: _stopVideo, // వదిలేస్తే
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _isRecording ? 90 : 80,
                    height: _isRecording ? 90 : 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isRecording ? 40 : 65,
                        height: _isRecording ? 40 : 65,
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.red : Colors.white,
                          borderRadius: BorderRadius.circular(
                            _isRecording ? 10 : 50,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ఫ్రంట్/బ్యాక్ కెమెరా మార్చే బటన్
                IconButton(
                  icon: const Icon(
                    Icons.flip_camera_ios,
                    color: Colors.white,
                    size: 40,
                  ),
                  onPressed: _switchCamera,
                ),
              ],
            ),
          ),

          // 🌟 4. రికార్డింగ్ టైమర్ (వీడియో తీస్తున్నప్పుడు)
          if (_isRecording)
            const Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Colors.red, size: 15),
                    SizedBox(width: 8),
                    Text(
                      "Recording...",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
