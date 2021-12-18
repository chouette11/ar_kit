import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'package:ar_kit/azblob.dart';
import 'package:ar_kit/webview.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:collection/collection.dart';

Future<void> main() async {
  await dotenv.load();

  String envKey = dotenv.get('CONNECTION_KEY');
  await dotenv.load(fileName: ".env");
  runApp(MaterialApp(home: MyApp(envKey: envKey)));
}

class MyApp extends StatefulWidget {
  MyApp({Key? key, required this.envKey}) : super(key: key);
  final String envKey;
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    final samples = [
      Sample(
        'Distance tracking',
        'Detects horizontal plane and track distance on it.',
        Icons.blur_on,
            () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (c) => DistanceTrackingPage(envKey: widget.envKey,))),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('ARKit Demo'),
      ),
      body: ListView(children: samples.map((s) => SampleItem(item: s)).toList()),
    );
  }
}

class SampleItem extends StatelessWidget {
  const SampleItem({
    required this.item,
    Key? key,
  }) : super(key: key);
  final Sample item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => item.onTap(),
        child: ListTile(
          leading: Icon(item.icon),
          title: Text(
            item.title,
            style: Theme.of(context).textTheme.subtitle1,
          ),
          subtitle: Text(
            item.description,
            style: Theme.of(context).textTheme.subtitle2,
          ),
        ),
      ),
    );
  }
}

class Sample {
  const Sample(this.title, this.description, this.icon, this.onTap);
  final String title;
  final String description;
  final IconData icon;
  final Function onTap;
}

class DistanceTrackingPage extends StatefulWidget {
  DistanceTrackingPage({Key? key, required this.envKey, }) : super(key: key);
  final String envKey;

  @override
  _DistanceTrackingPageState createState() => _DistanceTrackingPageState();
}

class _DistanceTrackingPageState extends State<DistanceTrackingPage> {

  var _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool isCapture = false;
  double distance = 0;

  dynamic _pickImageError;
  void onImageButtonPressed(ImageSource source,
      {BuildContext? context, bool isMultiImage = false}) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      setState(() {
        _imageFile = pickedFile!;
      });
    } catch (e) {
      setState(() {
        _pickImageError = e;
      });
    }
  }

  late ARKitController arkitController;
  ARKitPlane? plane;
  ARKitNode? node;
  String? anchorId;
  vector.Vector3? lastPosition;

  @override
  void dispose() {
    arkitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Distance Tracking Sample')),
    body: Container(
      child:
      isCapture ?
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
                height: MediaQuery.of(context).size.height - 200,
                child: Image.file(File(_imageFile.path))),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "これでいいですか？",
              style: TextStyle(
                fontSize: 24,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                RaisedButton(
                  child: Text("戻る"),
                  onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(builder: (c) => DistanceTrackingPage(envKey: widget.envKey,))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Uint8List content = await _imageFile!.readAsBytes();
                    await uploadImageToAzure(context, content, widget.envKey);
                    await Navigator.of(context).push<void>(
                        MaterialPageRoute(builder: (_) => WebViewScreen()));
                  },
                  child: Text("決定！"),
                ),
              ],
            ),
          )
        ],
      )
          : Stack(
        children:[
          ARKitSceneView(
            showFeaturePoints: true,
            planeDetection: ARPlaneDetection.horizontal,
            onARKitViewCreated: onARKitViewCreated,
            enableTapRecognizer: true,
          ),
          Text(distance.toString()),
        ],
      ),
    ),
    floatingActionButton: Visibility(
      visible: !isCapture,
      child: FloatingActionButton(
          onPressed: () {
            onImageButtonPressed(ImageSource.camera, context: context);
            isCapture = !isCapture;
            setState(() {});
          }
      ),
    ),
  );

  void onARKitViewCreated(ARKitController arkitController) {
    this.arkitController = arkitController;
    this.arkitController.onAddNodeForAnchor = _handleAddAnchor;
    this.arkitController.onUpdateNodeForAnchor = _handleUpdateAnchor;
    this.arkitController.onARTap = (List<ARKitTestResult> ar) {
      final planeTap = ar.firstWhereOrNull(
            (tap) => tap.type == ARKitHitTestResultType.existingPlaneUsingExtent,
      );
      if (planeTap != null) {
        _onPlaneTapHandler(planeTap.worldTransform);
        distance = planeTap.distance;
        setState(() {

        });
      }
    };
  }

  void _handleAddAnchor(ARKitAnchor anchor) {
    if (!(anchor is ARKitPlaneAnchor)) {
      return;
    }
    _addPlane(arkitController, anchor);
  }

  void _handleUpdateAnchor(ARKitAnchor anchor) {
    if (anchor.identifier != anchorId) {
      return;
    }
    final planeAnchor = anchor as ARKitPlaneAnchor;
    node!.position =
        vector.Vector3(planeAnchor.center.x, 0, planeAnchor.center.z);
    plane?.width.value = planeAnchor.extent.x;
    plane?.height.value = planeAnchor.extent.z;
  }

  void _addPlane(ARKitController controller, ARKitPlaneAnchor anchor) {
    anchorId = anchor.identifier;
    plane = ARKitPlane(
      width: anchor.extent.x,
      height: anchor.extent.z,
      materials: [
        ARKitMaterial(
          transparency: 0.5,
          diffuse: ARKitMaterialProperty.color(Colors.white),
        )
      ],
    );

    node = ARKitNode(
      geometry: plane,
      position: vector.Vector3(anchor.center.x, 0, anchor.center.z),
      rotation: vector.Vector4(1, 0, 0, -math.pi / 2),
    );
    controller.add(node!, parentNodeName: anchor.nodeName);
  }

  void _onPlaneTapHandler(Matrix4 transform) {
    final position = vector.Vector3(
      transform.getColumn(3).x,
      transform.getColumn(3).y,
      transform.getColumn(3).z,
    );
    final material = ARKitMaterial(
      lightingModelName: ARKitLightingModel.constant,
      diffuse: ARKitMaterialProperty.color(Color.fromRGBO(255, 153, 83, 1)),
    );
    final sphere = ARKitSphere(
      radius: 0.003,
      materials: [material],
    );
    final node = ARKitNode(
      geometry: sphere,
      position: position,
    );
    arkitController.add(node);
    if (lastPosition != null) {
      final line = ARKitLine(
        fromVector: lastPosition!,
        toVector: position,
      );
      final lineNode = ARKitNode(geometry: line);
      arkitController.add(lineNode);

      final distance = _calculateDistanceBetweenPoints(position, lastPosition!);
      final point = _getMiddleVector(position, lastPosition!);
      _drawText(distance, point);
    }
    lastPosition = position;
  }

  String _calculateDistanceBetweenPoints(vector.Vector3 A, vector.Vector3 B) {
    final length = A.distanceTo(B);
    return '${(length * 100).toStringAsFixed(2)} cm';
  }

  vector.Vector3 _getMiddleVector(vector.Vector3 A, vector.Vector3 B) {
    return vector.Vector3((A.x + B.x) / 2, (A.y + B.y) / 2, (A.z + B.z) / 2);
  }

  void _drawText(String text, vector.Vector3 point) {
    final textGeometry = ARKitText(
      text: text,
      extrusionDepth: 1,
      materials: [
        ARKitMaterial(
          diffuse: ARKitMaterialProperty.color(Colors.red),
        )
      ],
    );
    const scale = 0.001;
    final vectorScale = vector.Vector3(scale, scale, scale);
    final node = ARKitNode(
      rotation: vector.Vector4(1, 0, 0, -0.25 * math.pi),
      geometry: textGeometry,
      position: point,
      scale: vectorScale,
    );
    arkitController
        .getNodeBoundingBox(node)
        .then((List<vector.Vector3> result) {
      final minVector = result[0];
      final maxVector = result[1];
      final dx = (maxVector.x - minVector.x) / 2 * scale;
      final dy = (maxVector.y - minVector.y) / 2 * scale;
      final position = vector.Vector3(
        node.position.x - dx,
        node.position.y - dy,
        node.position.z,
      );
      node.position = position;
    });
    arkitController.add(node);
  }
}