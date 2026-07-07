import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

const _orientations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

InputImage? cameraImageToInputImage({
  required CameraImage image,
  required CameraDescription camera,
  required DeviceOrientation deviceOrientation,
}) {
  if (Platform.isIOS) {
    return _inputImageFromIos(image, camera);
  }
  return _inputImageFromAndroid(image, camera, deviceOrientation);
}

InputImage? _inputImageFromIos(
  CameraImage image,
  CameraDescription camera,
) {
  if (image.planes.isEmpty) return null;

  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  if (format == null) return null;

  final rotation = InputImageRotationValue.fromRawValue(
    camera.sensorOrientation,
  );
  if (rotation == null) return null;

  final plane = image.planes.first;
  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    ),
  );
}

InputImage? _inputImageFromAndroid(
  CameraImage image,
  CameraDescription camera,
  DeviceOrientation deviceOrientation,
) {
  final rotation = _androidRotation(camera, deviceOrientation);
  if (rotation == null) return null;

  final bytes = _toNv21Bytes(image);
  if (bytes == null) return null;

  return InputImage.fromBytes(
    bytes: bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.width,
    ),
  );
}

InputImageRotation? _androidRotation(
  CameraDescription camera,
  DeviceOrientation deviceOrientation,
) {
  final rotationCompensation = _orientations[deviceOrientation];
  if (rotationCompensation == null) return null;

  var degrees = rotationCompensation;
  if (camera.lensDirection == CameraLensDirection.front) {
    degrees = (camera.sensorOrientation + degrees) % 360;
  } else {
    degrees = (camera.sensorOrientation - degrees + 360) % 360;
  }

  return InputImageRotationValue.fromRawValue(degrees);
}

Uint8List? _toNv21Bytes(CameraImage image) {
  if (image.planes.isEmpty) return null;

  if (image.planes.length == 1) {
    return Uint8List.fromList(image.planes.first.bytes);
  }

  if (image.planes.length < 3) return null;

  final width = image.width;
  final height = image.height;
  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];

  final ySize = width * height;
  final uvSize = width * height ~/ 2;
  final nv21 = Uint8List(ySize + uvSize);

  var offset = 0;
  for (var row = 0; row < height; row++) {
    final rowStart = row * yPlane.bytesPerRow;
    nv21.setRange(offset, offset + width, yPlane.bytes, rowStart);
    offset += width;
  }

  final uvRowStride = uPlane.bytesPerRow;
  final uvPixelStride = uPlane.bytesPerPixel ?? 1;
  var uvIndex = ySize;
  for (var row = 0; row < height ~/ 2; row++) {
    for (var col = 0; col < width ~/ 2; col++) {
      final uvOffset = row * uvRowStride + col * uvPixelStride;
      if (uvOffset >= vPlane.bytes.length || uvOffset >= uPlane.bytes.length) {
        return null;
      }
      nv21[uvIndex++] = vPlane.bytes[uvOffset];
      nv21[uvIndex++] = uPlane.bytes[uvOffset];
    }
  }

  return nv21;
}
