import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'package:ar_kit/azblob.dart';
import 'package:ar_kit/webview.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:collection/collection.dart';

void main() => runApp(MaterialApp(theme: ThemeData(fontFamily: "Noto"),home: MyApp()));

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: HexColor("#ff99cc"),
        title: const Text('ARKit Demo'),
      ),
      body: Center(
        child: ElevatedButton(
          child: Text("aa"),
          onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (c) => DistanceTrackingPage())),
        ),
      ),
    );
  }
}

class DistanceTrackingPage extends StatefulWidget {

  @override
  _DistanceTrackingPageState createState() => _DistanceTrackingPageState();
}

class _DistanceTrackingPageState extends State<DistanceTrackingPage> {

  var _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool isCapture = false;
  bool isModal = true;
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
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
                height: MediaQuery.of(context).size.height * 0.64,
                child: Image.file(File(_imageFile.path))),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              "これでいいですか？",
              style: TextStyle(
                fontSize: 24,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RaisedButton(
                child: Text("戻る"),
                onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (c) => DistanceTrackingPage())),
              ),
              ElevatedButton(
                onPressed: () async {
                  Uint8List content = await _imageFile!.readAsBytes();
                  await uploadImageToAzure(context, content);
                  await Navigator.of(context).push<void>(
                      MaterialPageRoute(builder: (_) => WebViewScreen()));
                },
                child: Text("決定！"),
              ),
            ],
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
          Visibility(
            visible: isModal,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 20, left: 20),
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height * 0.4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(),
                    color: Colors.white
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                            "➀円の中心をタップ！\n",
                          style: TextStyle(
                            height: 1,
                            fontSize: 26,
                          ),
                        ),
                        Text(
                          "デバイスと円の距離から円大きさを求めます",
                          style: TextStyle(
                            height: 1
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Text(
                            "➁右下のボタンをタップ\n",
                            style: TextStyle(
                              height: 1,
                              fontSize: 26,
                            ),
                          ),
                        ),
                        Text(
                            "円がどれだけ真円に近いか解析します！",
                          style: TextStyle(
                            height: 1
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: ElevatedButton(
                              onPressed: () {
                                isModal = false;
                                setState(() {});
                              },
                              child: Text("OK!"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Text(distance.toString()),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton(
        onPressed: () {
          onImageButtonPressed(ImageSource.camera, context: context);
          isCapture = !isCapture;
          setState(() {});
        },
      child: Icon(
        Icons.camera_alt_outlined,
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

        _onPlaneTapHandler(planeTap!.worldTransform, planeTap!.distance);
        distance = planeTap.distance;
        setState(() {

        });

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

  void _onPlaneTapHandler(Matrix4 transform, double deviceDistance) {
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
      lastPosition = position;

      final distance = deviceDistance.toString();
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