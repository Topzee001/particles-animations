import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'animation/ribbon_painter.dart';
import 'animation/ribbon_scene.dart';

/// Sets the system bar appearance and starts the Flutter application.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF08080B),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

/// Supplies the shared theme and opens the particle experiment.
class MyApp extends StatelessWidget {
  /// Creates the application's root widget.
  const MyApp({super.key});

  /// Configures colours, control styles, and the starting screen.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Particle Ribbons',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF08080B),
        colorScheme: const ColorScheme.dark(
          primary: ribbonGold,
          secondary: ribbonViolet,
          surface: Color(0xFF151519),
          onPrimary: Color(0xFF201A0D),
        ),
        sliderTheme: const SliderThemeData(
          trackHeight: 2,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE1DFE8),
            side: const BorderSide(color: Color(0xFF33323A)),
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
      home: const RibbonExperiment(),
    );
  }
}

/// Displays the particle canvas and connects gestures to the scene model.
class RibbonExperiment extends StatefulWidget {
  /// Creates the interactive experiment screen.
  const RibbonExperiment({super.key});

  @override
  State<RibbonExperiment> createState() => _RibbonExperimentState();
}

/// Keeps the model, painter, and display ticker alive across widget rebuilds.
class _RibbonExperimentState extends State<RibbonExperiment>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // The model owns geometry, angles, settings, and spring motion.
  late final RibbonScene _scene;
  // Reuse one painter and its point buffers for the lifetime of this screen.
  late final RibbonPainter _painter;
  // Flutter calls this ticker when the display is ready for another frame.
  late final Ticker _ticker;
  // Previous ticker timestamp, used to calculate frame duration.
  Duration? _lastFrame;
  // Stops background work when the app is no longer visible.
  bool _foreground = true;

  /// Creates the scene and starts listening for frames and lifecycle changes.
  @override
  void initState() {
    super.initState();
    _scene = RibbonScene();
    _painter = RibbonPainter(_scene);
    _ticker = createTicker((elapsed) {
      final previous = _lastFrame;
      _lastFrame = elapsed;
      if (previous != null) {
        // Convert elapsed microseconds into the seconds expected by the model.
        _scene.advance((elapsed - previous).inMicroseconds / 1000000);
      }
    });
    _scene.addListener(_syncTicker);
    WidgetsBinding.instance.addObserver(this);
    _syncTicker();
  }

  /// Runs the display ticker only while the app is visible and playing.
  void _syncTicker() {
    final shouldRun = _scene.playing && _foreground;
    if (shouldRun && !_ticker.isActive) {
      // Discard the old timestamp so resuming does not create a large jump.
      _lastFrame = null;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
      _lastFrame = null;
    }
  }

  /// Suspends frame updates in the background and resumes them on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTicker();
  }

  /// Scatters particles and refreshes the pause button if playback resumes.
  void _scatter() {
    setState(_scene.scatter);
  }

  /// Opens sliders that update the existing scene's motion settings.
  Future<void> _showPhysics() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151519),
      showDragHandle: true,
      builder: (context) => _PhysicsPanel(scene: _scene, onScatter: _scatter),
    );
    // Reset or scatter inside the sheet may have changed playback state.
    if (mounted) setState(() {});
  }

  /// Releases listeners and the ticker when the screen is removed.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scene.removeListener(_syncTicker);
    _ticker.dispose();
    _scene.dispose();
    super.dispose();
  }

  /// Builds the header, gesture canvas, and controls around the live painter.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Hide extra text on short screens to leave room for the canvas.
            final compact = constraints.maxHeight < 500;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(24, compact ? 4 : 20, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: ribbonGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'MOTION STUDY  /  001',
                        style: TextStyle(
                          color: Color(0xFFA5A1AE),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: _scene.playing
                            ? 'Pause animation'
                            : 'Resume animation',
                        onPressed: () => setState(_scene.togglePlaying),
                        icon: Icon(
                          _scene.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 22,
                        ),
                        color: const Color(0xFFC4C0CD),
                      ),
                    ],
                  ),
                ),
                if (!compact)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 17, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order in motion.',
                          style: TextStyle(
                            fontSize: 35,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -1.6,
                            color: Color(0xFFF3F0F7),
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          'A little maths. Thousands of particles.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF898592),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  // Describe the canvas and expose its tap action to readers.
                  child: Semantics(
                    label: 'Gold and violet particle ribbons. Tap to scatter; drag to orbit.',
                    button: true,
                    onTap: _scatter,
                    // Gesture callbacks change the model's view or springs.
                    child: GestureDetector(
                      key: const ValueKey('particle-stage'),
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: _scatter,
                      onPanStart: (_) => _scene.beginOrbit(),
                      onPanUpdate: (details) =>
                          _scene.drag(details.delta.dx, details.delta.dy),
                      onPanEnd: (details) =>
                          _scene.endOrbit(details.velocity.pixelsPerSecond.dx),
                      onPanCancel: () => _scene.endOrbit(0),
                      // Isolate animation repaints from the surrounding UI.
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _painter,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, compact ? 8 : 24),
                  child: Column(
                    children: [
                      if (!compact) ...[
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              size: 14,
                              color: Color(0xFF74707E),
                            ),
                            SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                'Drag to orbit  ·  Tap to scatter',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF898592),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _scatter,
                              icon: const Icon(Icons.blur_on_rounded, size: 20),
                              label: const Text('Scatter'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showPhysics,
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: const Text('Physics'),
                            ),
                          ),
                        ],
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 20),
                        Text(
                          '${(_scene.particles.length / 1000).toStringAsFixed(1)}k particles'
                          '   /   Drawn live in Flutter',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF625E6B),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Holds the rotation and spring controls shown in the bottom sheet.
class _PhysicsPanel extends StatefulWidget {
  const _PhysicsPanel({required this.scene, required this.onScatter});

  final RibbonScene scene;
  final VoidCallback onScatter;

  @override
  State<_PhysicsPanel> createState() => _PhysicsPanelState();
}

/// Refreshes slider labels when the user changes a physics setting.
class _PhysicsPanelState extends State<_PhysicsPanel> {
  /// Builds the three sliders, spring formula, reset, and scatter actions.
  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    return SafeArea(
      top: false,
      // Allow the controls to scroll on smaller screens.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The shape of a spring.',
              style: TextStyle(fontSize: 24, letterSpacing: -0.7),
            ),
            const SizedBox(height: 9),
            const Text(
              'Stiffness pulls each particle home. Damping takes the bounce out. Change a value, then scatter.',
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: Color(0xFFA6A1B1),
              ),
            ),
            const SizedBox(height: 20),
            _control(
              'Rotation',
              '${scene.speed.toStringAsFixed(2)} rad/s',
              scene.speed,
              0,
              1.8,
              (value) => scene.tune(speed: value),
            ),
            _control(
              'Stiffness',
              scene.stiffness.toStringAsFixed(0),
              scene.stiffness,
              15,
              130,
              (value) => scene.tune(stiffness: value),
            ),
            _control(
              'Damping',
              scene.damping.toStringAsFixed(1),
              scene.damping,
              1,
              20,
              (value) => scene.tune(damping: value),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 22),
              child: Text(
                'F = −kx − cv    ·    mass = 1',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF817A8F),
                ),
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(scene.reset),
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Reset'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    widget.onScatter();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.blur_on_rounded, size: 20),
                  label: const Text('Try it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds one labelled slider and forwards its value to the scene.
  Widget _control(
    String label,
    String displayValue,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text(
              displayValue,
              style: const TextStyle(fontSize: 12, color: ribbonGold),
            ),
          ],
        ),
        Slider(
          label: label,
          value: value,
          min: min,
          max: max,
          onChanged: (value) => setState(() => onChanged(value)),
        ),
        const SizedBox(height: 9),
      ],
    );
  }
}
