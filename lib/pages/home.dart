import 'package:flutter/material.dart';
import 'package:noa/pages/noa.dart';
import 'package:noa/pages/tune.dart';
import 'package:noa/pages/hack.dart';
import 'package:noa/pages/account.dart';
import 'package:noa/util/switch_page.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _rotation = 0;
  String _selectedColor = 'Smokey black';

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
    _loadSavedColor();
  }

  void _loadSavedColor() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedColor = prefs.getString('selectedColor') ?? 'Smokey black';
    });
  }

  void _saveSelectedColor(String color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedColor', color);
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

  String _getModelFile(String color) {
    String modelFile;
    switch (color) {
      case 'Cool gray':
        modelFile = 'assets/models/3dframemodel_coolGray.glb';
        break;
      case 'H20':
        modelFile = 'assets/models/3dframemodel_h20.glb';
        break;
      case 'Smokey black':
      default:
        modelFile = 'assets/models/3dframemodel_smokeyBlack.glb';
        break;
    }
    return modelFile;
  }

  @override
  Widget build(BuildContext context) {
    // Add this line to set the status bar color to black
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
                  GestureDetector(
                    onTap: () => _showColorOptionsModal(context),
                    child: Icon(Icons.settings, size: 24, color: Colors.black),
                  ),
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
                      key: ValueKey(_selectedColor),
                      scale: "2 2 2",
                      src: _getModelFile(_selectedColor),
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

  void _showColorOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 20.0),
                child: Text(
                  'Customize your Frame',
                  style: TextStyle(
                    fontFamily: 'Pixelify Sans',
                    fontSize: 22,
                    fontVariations: [
                      FontVariation('wght', 450),
                    ],
                  ),
                ),
              ),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 0.8,
                children: [
                  _buildColorOption('Smokey black', 'assets/images/frameSelector_smokeyBlack.png'),
                  _buildColorOption('Cool gray', 'assets/images/frameSelector_coolGray.png'),
                  _buildColorOption('H20', 'assets/images/frameSelector_h20.png'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColorOption(String color, String imagePath) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
        });
        _saveSelectedColor(color);
        Navigator.pop(context);
        // Force a rebuild of the ModelViewer
        setState(() {});
      },
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Color.fromRGBO(245, 245, 245, 1),
          borderRadius: BorderRadius.circular(0),
          border: Border.all(
            color: _selectedColor == color ? Colors.black : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                color,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _selectedColor == color ? FontWeight.bold : FontWeight.normal,
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