import 'package:custom_image_cutter/custom_image_cutter.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const MyHomePage(title: 'Flutter Demo Home Page'));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final cropImage = GlobalKey();
  final controller = CustomImageCutterController();

  @override
  void initState() {
    controller.scaleNotifier.addListener(() => setState(() {}));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                SizedBox(
                  width: screenWidth, // 50% of screen width
                  height: screenHeight * 0.5, // 50% of screen height
                  child: CustomImageCutter(
                    minWidth: screenWidth * 0.5,
                    minHeight: screenHeight * 0.5,
                    isVertical: true,
                    backgroundColor: Colors.white,
                    controller: controller,
                    cropperKey: cropImage,
                    imagePath: 'image_path',
                    imageCover: 'assets/images/frame.png',
                    image: Image.network(
                      'https://nmwa.org/wp-content/uploads/2020/01/1993.76-GAP.jpg',
                    ),
                  ),
                ),
              ],
            ),
            Slider(
                min: controller.minScale,
                max: controller.maxScale,
                value: controller.scale,
                onChanged: (value) =>
                    setState(() => controller.updateScale(value))),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final cropped = await controller.crop(cropperKey: cropImage);
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (context) => Scaffold(
                appBar: AppBar(),
                body: Center(child: Image.memory(cropped!)),
              ),
              fullscreenDialog: true,
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
