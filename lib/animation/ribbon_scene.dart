import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';

/// Stores one particle's home position, scatter direction, and drawing style.
class RibbonParticle {
  /// Creates a particle; ribbon 0 is gold and ribbon 1 is violet.
  const RibbonParticle({
    required this.x,
    required this.y,
    required this.z,
    required this.scatterX,
    required this.scatterY,
    required this.scatterZ,
    required this.ribbon,
    required this.channel,
    required this.edge,
    required this.brightness,
  });

  /// Home coordinates: x is horizontal, y is vertical, and z is depth.
  final double x, y, z;

  /// Direction and distance to scatter when the spring is displaced.
  final double scatterX, scatterY, scatterZ;

  /// Colour group (ribbon) and spring response group (channel).
  final int ribbon, channel;

  /// True for particles on the arrow outline.
  final bool edge;

  /// A fixed brightness variation that makes the surface less uniform.
  final double brightness;
}

/// Owns the arrow geometry, animation state, and spring simulations.
class RibbonScene extends ChangeNotifier {
  /// A fixed seed recreates the same particle layout on each launch.
  RibbonScene({int seed = 73}) : particles = _makeParticles(seed);

  /// Number of interior particles per arrow.
  static const int surfaceCount = 6000;

  /// Number of outline particles per arrow.
  static const int edgeCount = 1600;

  /// Number of spring response groups shared by the particles.
  static const int channelCount = 12;

  /// Angular span per arrow in radians; 1.72π is about 310 degrees.
  static const double arrowLength = math.pi * 1.72;

  /// Angular span of the triangular head, in radians.
  static const double headLength = 0.64;

  /// Half the shaft's vertical thickness, in scene units.
  static const double shaftHalfHeight = 0.40;

  /// Half the head's vertical height, in scene units.
  static const double headHalfHeight = 0.91;

  /// Particle home positions are generated once, then reused every frame.
  final List<RibbonParticle> particles;
  // Each channel supplies one spring displacement to many particles.
  final List<_SpringChannel> _channels = List.generate(
    channelCount,
    (_) => _SpringChannel(),
  );

  /// Whether the animation clock and springs advance.
  bool playing = true;

  /// Automatic rotation speed, in radians per second.
  double speed = 0.72;

  /// Spring strength: larger values pull particles home faster.
  double stiffness = 56;

  /// Spring resistance: larger values remove bounce faster.
  double damping = 6.8;

  /// Accumulated simulation time, in seconds.
  double time = 0;

  /// Accumulated automatic rotation angle, in radians.
  double rotation = 0;

  /// Extra viewing angle added by horizontal dragging, in radians.
  double orbit = 0;

  /// Viewing tilt controlled by vertical dragging, in radians.
  double tilt = -0.35;
  // Remaining horizontal spin after releasing a drag, in radians per second.
  double _orbitVelocity = 0;
  // Stops release momentum from fighting an active drag.
  bool _dragging = false;

  /// Returns how far a spring group is displaced from home.
  double displacement(int channel) => _channels[channel].value;

  /// True while at least one scatter spring is still moving.
  bool get isScattered => _channels.any((channel) => channel.active);

  /// Advances the shared rotation and springs by one frame's elapsed seconds.
  void advance(double seconds) {
    if (!playing || seconds <= 0) return;
    // Ignore long gaps when returning from the background.
    final dt = math.min(seconds, 0.05);
    time += dt;
    // Angle = previous angle + angular speed × elapsed time.
    rotation += speed * dt;
    if (!_dragging) {
      orbit += _orbitVelocity * dt;
      // Exponential decay slows released drags consistently across frame rates.
      _orbitVelocity *= math.exp(-3.5 * dt);
    }
    for (final channel in _channels) {
      channel.advance(dt);
    }
    // The painter listens here and redraws without rebuilding the controls.
    notifyListeners();
  }

  /// Pauses or resumes both automatic rotation and spring movement.
  void togglePlaying() {
    playing = !playing;
    notifyListeners();
  }

  /// Starts a new drag and discards momentum from the previous one.
  void beginOrbit() {
    _dragging = true;
    _orbitVelocity = 0;
  }

  /// Converts finger movement in pixels into viewing angles.
  void drag(double dx, double dy) {
    orbit += dx * 0.009;
    tilt = (tilt + dy * 0.004).clamp(-0.85, 0.65);
    notifyListeners();
  }

  /// Converts release speed into limited orbit momentum.
  void endOrbit(double pixelsPerSecond) {
    _dragging = false;
    _orbitVelocity = (pixelsPerSecond * 0.009).clamp(-5.0, 5.0);
  }

  /// Adds an outward spring impulse and resumes a paused animation.
  void scatter() {
    playing = true;
    for (var i = 0; i < _channels.length; i++) {
      // Preserve position and velocity when another tap interrupts a spring.
      _restartSpring(i, impulse: 7.8 + (i % 4) * 0.65);
    }
    notifyListeners();
  }

  /// Updates slider settings while preserving active spring motion.
  void tune({double? speed, double? stiffness, double? damping}) {
    this.speed = speed ?? this.speed;
    this.stiffness = stiffness ?? this.stiffness;
    this.damping = damping ?? this.damping;
    if (stiffness != null || damping != null) {
      for (var i = 0; i < _channels.length; i++) {
        if (_channels[i].active) _restartSpring(i);
      }
    }
    notifyListeners();
  }

  /// Restores the starting settings, orientation, and particle positions.
  void reset() {
    speed = 0.72;
    stiffness = 56;
    damping = 6.8;
    tilt = -0.35;
    orbit = 0;
    time = 0;
    rotation = 0;
    _orbitVelocity = 0;
    _dragging = false;
    playing = true;
    for (final channel in _channels) {
      channel.reset();
    }
    notifyListeners();
  }

  /// Recreates one spring from its current position and velocity.
  void _restartSpring(int index, {double impulse = 0}) {
    final channel = _channels[index];
    channel.start(
      SpringDescription(
        mass: 1,
        // Small strength differences make groups return at different rates.
        stiffness: stiffness * (0.8 + index * 0.037),
        damping: damping,
      ),
      impulse,
    );
  }

  /// Samples two flat arrows and wraps their points around a unit cylinder.
  static List<RibbonParticle> _makeParticles(int seed) {
    final random = math.Random(seed);
    final particles = <RibbonParticle>[];
    // The shoulder is where the rectangular shaft meets the triangular head.
    const shoulder = arrowLength - headLength;

    // u runs from the tail (0) to the tip (arrowLength).
    void add(double u, double y, int ribbon, bool edge) {
      // Centre the arrow's angular span around zero.
      final angle = u - arrowLength / 2;
      // Tiny radius variations give the ribbon a little surface texture.
      final radius = 1 + (random.nextDouble() - 0.5) * 0.014;
      // Sine and cosine wrap a flat horizontal coordinate around a circle.
      final x = radius * math.cos(angle);
      final z = radius * math.sin(angle);
      particles.add(
        RibbonParticle(
          x: x,
          // Place gold slightly above violet in the current design.
          y: y + (ribbon == 0 ? -0.045 : 0.045),
          z: z,
          scatterX:
              x * (0.5 + random.nextDouble()) +
              (random.nextDouble() - 0.5) * 0.9,
          // Seeded offsets give each particle its own scatter direction.
          scatterY: (random.nextDouble() - 0.5) * 2.7,
          scatterZ:
              z * (0.5 + random.nextDouble()) +
              (random.nextDouble() - 0.5) * 0.9,
          ribbon: ribbon,
          channel: random.nextInt(channelCount),
          edge: edge,
          brightness: 0.35 + random.nextDouble() * 0.65,
        ),
      );
    }

    // Both colours use the same dimensions and particle counts.
    for (var ribbon = 0; ribbon < 2; ribbon++) {
      // Keep random points only when they fall inside the arrow.
      var accepted = 0;
      while (accepted < surfaceCount) {
        final u = random.nextDouble() * arrowLength;
        final y = (random.nextDouble() * 2 - 1) * headHalfHeight;
        // The shaft stays thick; the head narrows linearly to its tip.
        final halfHeight = u < shoulder
            ? shaftHalfHeight
            : headHalfHeight * (arrowLength - u) / headLength;
        if (y.abs() <= halfHeight) {
          add(u, y, ribbon, false);
          accepted++;
        }
      }

      // Walk around the shaft and triangular head to define their outline.
      final outline = <math.Point<double>>[
        const math.Point(0, -shaftHalfHeight),
        const math.Point(shoulder, -shaftHalfHeight),
        const math.Point(shoulder, -headHalfHeight),
        const math.Point(arrowLength, 0),
        const math.Point(shoulder, headHalfHeight),
        const math.Point(shoulder, shaftHalfHeight),
        const math.Point(0, shaftHalfHeight),
      ];
      // Segment lengths let us distribute edge particles by distance.
      final lengths = List.generate(outline.length, (i) {
        return outline[i].distanceTo(outline[(i + 1) % outline.length]);
      });
      final perimeter = lengths.reduce((a, b) => a + b);
      for (var i = 0; i < edgeCount; i++) {
        // Pick a distance around the full outline, with slight random jitter.
        var distance = (i + random.nextDouble()) / edgeCount * perimeter;
        var segment = 0;
        // Find the outline segment containing that distance.
        while (segment < lengths.length - 1 && distance > lengths[segment]) {
          distance -= lengths[segment++];
        }
        final a = outline[segment];
        final b = outline[(segment + 1) % outline.length];
        // t is progress from the segment's start (0) to its end (1).
        final t = distance / lengths[segment];
        add(
          a.x + (b.x - a.x) * t + (random.nextDouble() - 0.5) * 0.009,
          a.y + (b.y - a.y) * t + (random.nextDouble() - 0.5) * 0.009,
          ribbon,
          true,
        );
      }
    }
    // Motion changes the rendered positions, not this list of home positions.
    return List.unmodifiable(particles);
  }
}

/// Shares one damped spring's position and velocity across a particle group.
class _SpringChannel {
  // Flutter solves the spring equation from elapsed time.
  SpringSimulation? _simulation;
  // Seconds since the current spring simulation began.
  double _elapsed = 0;
  // Zero means home; positive and negative values lie on either side.
  double value = 0;
  // Current rate of displacement change, in scene units per second.
  double velocity = 0;

  /// True until the spring settles within Flutter's resting tolerance.
  bool get active => _simulation != null;

  /// Keeps the current displacement and adds the requested velocity impulse.
  void start(SpringDescription description, double impulse) {
    _simulation = SpringSimulation(
      description,
      value,
      0, // The spring's target is always the particle's home position.
      (velocity + impulse).clamp(-14.0, 14.0),
    );
    _elapsed = 0;
  }

  /// Samples the spring's position and velocity at its new elapsed time.
  void advance(double dt) {
    final simulation = _simulation;
    if (simulation == null) return;
    _elapsed += dt;
    value = simulation.x(_elapsed);
    velocity = simulation.dx(_elapsed);
    if (simulation.isDone(_elapsed)) reset();
  }

  /// Clears the simulation and snaps any tiny resting error to zero.
  void reset() {
    _simulation = null;
    value = 0;
    velocity = 0;
  }
}
