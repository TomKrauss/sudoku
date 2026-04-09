// The MIT License (MIT)
//
// Copyright © 2026 <copyright holders>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sudoku/model.dart';

class CameraWidget extends StatefulWidget {
  const CameraWidget({super.key});

  @override
  State<CameraWidget> createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget> {
  CameraController? cameraController;
  String? noCameraText = "Waiting for Camera to initialize";

  Future<void> initCameras() async {
    var cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      cameraController = CameraController(cameras[0], ResolutionPreset.max);
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

  Future<void> _takePicture() async {
    var controller = cameraController;
    if (controller == null) {
      return;
    }
    var file = await controller.takePicture();
    await file.readAsBytes();
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

