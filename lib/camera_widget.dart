// The MIT License (MIT)
//
// Copyright © 2026 <copyright holders>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:sudoku/model.dart';

class CameraWidget extends StatefulWidget {
  const CameraWidget({super.key});

  @override
  State<CameraWidget> createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget> {
  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  CameraController? cameraController;
  CameraDescription? currentCamera;
  String? noCameraText = "Waiting for Camera to initialize";

  Future<void> initCameras() async {
    var cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      currentCamera = cameras[0];
      cameraController = CameraController(currentCamera!, ResolutionPreset.max);
      await cameraController!
          .initialize()
          .then((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          noCameraText = null;
        });
      }).catchError((Object e) {
        if (e is CameraException) {
          setState(() {
            noCameraText = "Cannot use camera. Error is ${e.code}.";
          });
          switch (e.code) {
            case 'CameraAccessDenied':
              Games.logger.e("Cannot access camera. Access denied");
              break;
            default:
              Games.logger.e("Cannot use camera. Error ${e.code}");
              break;
          }
        }
      });
    }
  }
  
  @override
  void dispose() {
    super.dispose();
    cameraController?.dispose();
  }
  
  @override
  void initState() {
    super.initState();
    initCameras();
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (cameraController == null) {
      return null;
    }
    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/android/src/main/java/com/google_mlkit_commons/InputImageConverter.java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/ios/Classes/MLKVisionImage%2BFlutterPlugin.m
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/example/lib/vision_detector_views/painters/coordinates_translator.dart
    final camera = currentCamera!;
    final sensorOrientation = camera.sensorOrientation;
    // print(
    //     'lensDirection: ${camera.lensDirection}, sensorOrientation: $sensorOrientation, ${_controller?.value.deviceOrientation} ${_controller?.value.lockedCaptureOrientation} ${_controller?.value.isCaptureOrientationLocked}');
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) {
        return null;
      }
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      // print('rotationCompensation: $rotationCompensation');
    }
    if (rotation == null) {
      return null;
    }
    // print('final rotation: $rotation');

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) {
      return null;
    }
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  void textDetected(List<TextBlock> text) {
    for (final b in text) {
      b.text;
    }
  }

  Future<void> _takePicture() async {
    var controller = cameraController;
    if (controller == null) {
      return;
    }
    if (!controller.supportsImageStreaming()) {
      final picture = await controller.takePicture();
      final image = InputImage.fromFilePath(picture.path);
      var text = await _textRecognizer.processImage(image);
      textDetected(text.blocks);
      return;
    }
    await controller.startImageStream((cameraImage) async {
      var image = _inputImageFromCameraImage(cameraImage);
      if (image != null) {
        await controller.stopImageStream();
        var text = await _textRecognizer.processImage(image);
        textDetected(text.blocks);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var controller = cameraController;
    if (controller == null || noCameraText != null) {
      return Center(child: Text(noCameraText ?? "Loading Camera"),);
    }
    return Column(children: [
      CameraPreview(controller),
      SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [ElevatedButton(onPressed: _takePicture, child: Text("Scan"))],)
    ]);
  }
}

