import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class CustomImageCutter extends StatefulWidget {
  final GlobalKey cropperKey;
  final Color overlayColor;
  final Color backgroundColor;
  final Image image;
  final String imagePath;
  final String imageCover;
  final double maxScale;

  final bool isVertical;
  final CustomImageCutterController controller;

  final double minHeight;
  final double minWidth;

  const CustomImageCutter({
    super.key,
    required this.cropperKey,
    required this.image,
    required this.imagePath,
    required this.imageCover,
    required this.controller,
    this.maxScale = 5.0,
    required this.minHeight,
    required this.minWidth,
    required this.isVertical,
    this.backgroundColor = Colors.transparent,
    this.overlayColor = Colors.white,
  });

  @override
  State<CustomImageCutter> createState() => _CustomImageCutterState();
}

class _CustomImageCutterState extends State<CustomImageCutter> {
  String imagePath = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
    widget.controller._maxScale = widget.maxScale;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    Completer<ui.Image> completer = Completer<ui.Image>();
    widget.image.image.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener(
            (ImageInfo info, bool _) => completer.complete(info.image)));

    return FutureBuilder<ui.Image>(
      future: completer.future,
      builder: (BuildContext context, AsyncSnapshot<ui.Image> snapshot) {
        if (snapshot.hasData &&
            widget.imagePath != imagePath &&
            completer.isCompleted) {
          imagePath = widget.imagePath;
          controller._initImageOriginalSize(
            height: snapshot.data!.height.toDouble(),
            width: snapshot.data!.width.toDouble(),
          );
          controller._centerImage();
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            double containerWidth = constraints.maxWidth;
            double containerHeight = constraints.maxHeight;
            if (containerHeight < widget.minHeight) {
              containerHeight = widget.minHeight;
              containerWidth = widget.minWidth;
            }
            controller._initContainerSize(containerWidth, containerHeight);
            return Stack(
              children: [
                GestureDetector(
                  onScaleUpdate: (ScaleUpdateDetails details) {
                    switch (details.pointerCount) {
                      case 1:
                        controller._onDrag(details);
                        break;
                      case 2:
                        controller._onScale(details.scale);
                        break;
                      default:
                        return;
                    }
                  },
                  child: ClipRect(
                    clipBehavior: Clip.antiAlias,
                    child: ColoredBox(
                      color: widget.backgroundColor,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: containerWidth,
                            height: containerHeight,
                            child: RepaintBoundary(
                              key: widget.cropperKey,
                              child: Transform.translate(
                                offset: controller._offset,
                                child: Transform.scale(
                                  scale: controller._imageScale *
                                      2.5, // Double the initial scale
                                  child: widget.image,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: SizedBox(
                              height: containerHeight,
                              width: containerWidth,
                              child: Container(
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage(
                                      widget.imageCover,
                                    ),
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class CustomImageCutterController extends ChangeNotifier {
  double _containerWidth = 0;
  double _containerHeight = 0;
  double _imageHeight = 0;
  double _imageWidth = 0;
  double _imageScale = 2.5;
  double _xOffset = 0.0;
  double _yOffset = 0.0;
  double _maxScale = 5.0;
  double _lastScaleValue = 0.0;
  double _minScale = 0.0;

  ValueNotifier<double> scaleNotifier = ValueNotifier<double>(0.0);

  double get maxScale => _maxScale;
  double get minScale => _minScale;
  double get scale => scaleNotifier.value;

  double get _maxYDisplacement => _maxDisplacement(isXAxis: false);
  double get _maxXDisplacement => _maxDisplacement(isXAxis: true);

  double _calculateNewResizedSize(
      {required double originalBiggerSide,
      required double originalSmallerSide,
      required double newWidth}) {
    double ratio = newWidth / originalSmallerSide;
    double newSize = ratio * originalBiggerSide;
    return newSize;
  }

  double _maxDisplacement({required bool isXAxis}) {
    final scale = _imageScale / _minScale;
    final displacement = isXAxis
        ? _imageWidth * scale - _containerWidth
        : _imageHeight * scale - _containerHeight;
    final difference = displacement / 2;
    return difference;
  }

  bool get _isInsideOfYOffset =>
      _yOffset >= -_maxYDisplacement && _yOffset <= _maxYDisplacement;
  bool get _isInsideOfXOffset =>
      _xOffset >= -_maxXDisplacement && _xOffset <= _maxXDisplacement;
  bool get _isPortrait => _imageHeight > _imageWidth;
  bool get _isSquare => _imageHeight == _imageWidth;

  Offset get _offset => Offset(_xOffset, _yOffset);

  void _initContainerSize(double width, double height) {
    _containerWidth = width;
    _containerHeight = height;
  }

  void _initImageOriginalSize({required double height, required double width}) {
    _imageWidth = width;
    _imageHeight = height;

    if (_imageHeight / _containerHeight < _imageWidth / _containerWidth) {
      _imageScale = _containerHeight / _imageHeight;
    } else {
      _imageScale = _containerWidth / _imageWidth;
    }

    _minScale = _imageScale;
    _maxScale = _imageScale * 3;
    _centerImage();
    scaleNotifier.value = (_minScale + _maxScale) / 2;
  }

  void _centerImage() {
    _xOffset = 0.0;
    _yOffset = 0.0;
    notifyListeners();
  }

  void reset() {
    _xOffset = 0.0;
    _yOffset = 0.0;
    _imageHeight = 0;
    _imageWidth = 0;
    _imageScale = _minScale;
    scaleNotifier.value = _imageScale;

    notifyListeners();
  }

  Future<Uint8List?> crop(
      {required GlobalKey cropperKey, double pixelRatio = 2}) async {
    final renderObject = cropperKey.currentContext!.findRenderObject();
    final boundary = renderObject as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);

    // Defining the crop area
    final Rect cropRect = Rect.fromLTWH(
      (_containerWidth * 0.0001) * pixelRatio,
      (_containerHeight * 0.0001) * pixelRatio,
      (_containerWidth) * pixelRatio,
      (_containerHeight) * pixelRatio,
    );

    // Cropping the image
    final ui.Image croppedImage = await _cropImage(image, cropRect);

    final byteData =
        await croppedImage.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData?.buffer.asUint8List();
    return pngBytes;
  }

  Future<ui.Image> _cropImage(ui.Image image, Rect cropRect) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, cropRect);
    final paint = Paint();
    canvas.drawImageRect(image, cropRect,
        Rect.fromLTWH(0, 0, cropRect.width, cropRect.height), paint);
    final croppedPicture = recorder.endRecording();
    return await croppedPicture.toImage(
        cropRect.width.toInt(), cropRect.height.toInt());
  }

  void updateScale(double newValue) {
    double scale = newValue;
    if (scale < _minScale) scale = _minScale;
    if (newValue > _maxScale) scale = maxScale;
    _setScale(scale);
  }

  void _onScale(double newValue) {
    double scaleFactor = newValue > _lastScaleValue
        ? newValue - _lastScaleValue
        : newValue - _lastScaleValue;
    _lastScaleValue = newValue;

    if (scaleFactor > 0.2 || scaleFactor < -0.2) return;

    scaleFactor = scaleFactor < 0 ? scaleFactor * 2 : scaleFactor;
    double scale = _imageScale + scaleFactor;
    if (scale < _minScale) return;
    if (scale > _maxScale) return;
    _setScale(scale);
  }

  void _setScale(double scale) {
    if (_imageScale > scale) {
      final zoomOutInteractions = _imageScale - scale;
      for (int interaction = 0;
          interaction < zoomOutInteractions;
          interaction++) {
        _updateOffsetInsideBoundaries();
        _imageScale = scale;
        scaleNotifier.value = _imageScale;
      }
      _updateOffsetInsideBoundaries();
    } else {
      _imageScale = scale;
      scaleNotifier.value = _imageScale;
      notifyListeners();
    }
  }

  void _onDrag(ScaleUpdateDetails details) {
    final xOffsetTemp = _xOffset + details.focalPointDelta.dx;
    final yOffsetTemp = _yOffset + details.focalPointDelta.dy;

    _updateOffset(xOffsetTemp: xOffsetTemp, yOffsetTemp: yOffsetTemp);
  }

  void _updateOffset(
      {required double yOffsetTemp, required double xOffsetTemp}) {
    if (yOffsetTemp >= -_maxYDisplacement && yOffsetTemp <= _maxYDisplacement) {
      _yOffset = yOffsetTemp;
    }

    if (xOffsetTemp >= -_maxXDisplacement && xOffsetTemp <= _maxXDisplacement) {
      _xOffset = xOffsetTemp;
    }
    notifyListeners();
  }

  void _updateOffsetInsideBoundaries() {
    if (!_isInsideOfYOffset && _yOffset != 0) {
      _yOffset =
          _yOffset > _maxYDisplacement ? _maxYDisplacement : -_maxYDisplacement;
    }
    if (!_isInsideOfXOffset && _xOffset != 0) {
      _xOffset =
          _xOffset > _maxXDisplacement ? _maxXDisplacement : -_maxXDisplacement;
    }
    notifyListeners();
  }
}
