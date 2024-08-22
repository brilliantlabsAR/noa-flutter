import 'package:flutter/material.dart';
import 'package:noa/pages/noa.dart';
import 'package:noa/pages/tune.dart';
import 'package:noa/pages/hack.dart';
import 'package:noa/pages/notes.dart';
import 'package:noa/pages/account.dart';
import 'package:noa/widgets/top_title_bar.dart';
import 'package:noa/util/switch_page.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart'; // Import the model_viewer_plus package

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _rotation = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
    _controller.forward().then((_) {
      _controller.dispose();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _rotation += details.primaryDelta! * 0.5;
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Image.asset(
                  'assets/images/brilliant_logo_black.png',
                  width: 140,
                ),
              ),
              SizedBox(height: 24),
              Expanded(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: 250),
                  child: _buildFullWidthTile(),
                ),
              ),
              SizedBox(height: 10),
              GridView.count(
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.43,
                children: [
                  _buildTile(context, 'Noa', const NoaPage(), 'View your past interactions with Noa.', Icons.question_answer),
                  _buildTile(context, 'Tune', const TunePage(), 'Tune your experience with Noa.', Icons.tune),
                  _buildTile(context, 'Hack', const HackPage(), 'Hack your Frame.', Icons.code),
                  _buildTile(context, 'Profile', const AccountPage(), 'Manage your Brilliant Labs account.', Icons.person),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthTile() {
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      child: Container(
        constraints: BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: Color.fromRGBO(245, 245, 245, 1),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Frames', 
                    style: TextStyle(
                      fontFamily: 'Pixelify Sans',
                      fontSize: 17, 
                      fontVariations: [
                          FontVariation('wght', 450)
                      ],
                    )
                  ),
                  Text('80% battery', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return ModelViewer(
                      scale: "2 2 2",
                      src: 'assets/models/3dframemodel.glb',
                      alt: "Frame 3d model",
                      ar: true,
                      autoRotate: true,
                      autoRotateDelay: 0,
                      rotationPerSecond: "30deg",
                      cameraControls: true,
                      disableZoom: true,
                      minCameraOrbit: "auto 90deg auto",
                      maxCameraOrbit: "auto 90deg auto",
                      cameraOrbit: "${_rotation}deg 75deg 105%",
                      interpolationDecay: 200,
                      orbitSensitivity: 1,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, String title, Widget page, String subtitle, IconData icon) {
    return GestureDetector(
      onTap: () => switchPage(context, page),
      child: Container(
        decoration: BoxDecoration(
          color: Color.fromRGBO(245, 245, 245, 1),
          borderRadius: BorderRadius.circular(0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Icon(icon, color: Colors.black, size: 25),
              ),
              Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Pixelify Sans',
                  color: Colors.black, 
                  fontSize: 17, 
                  fontVariations: [
                    FontVariation('wght', 450),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.black, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}