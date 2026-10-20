import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ribbon_scene.dart';

/// Colour used by ribbon 0.
const ribbonGold = Color(0xFFF2CD75);

/// Colour used by ribbon 1.
const ribbonViolet = Color(0xFF9A7BFF);

/// Projects the scene's 3D particles onto Flutter's 2D canvas.
class RibbonPainter extends CustomPainter {
  /// Repaints when the scene changes, skipping widget build and layout.
  RibbonPainter(this.scene) : super(repaint: scene);

  /// Shared geometry and motion state supplied by the screen.
  final RibbonScene scene;
  // Eight brightness buckets avoid a separate drawing call for every particle.
  static const _levels = 8;
  // Four groups: gold surface, gold edge, violet surface, and violet edge.
  final _batches = List.generate(_levels * 4, (index) {
    final edge = (index ~/ _levels).isOdd;
    return _PointBatch(edge ? RibbonScene.edgeCount : RibbonScene.surfaceCount);
  });
  final _paint = Paint()
    ..strokeCap = StrokeCap.round
    // Add overlapping light rather than covering the previous colour.
    ..blendMode = BlendMode.plus
    ..isAntiAlias = true;

  /// Transforms, projects, groups, and draws all particles for this frame.
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    // Keep scattered particles inside the animation area.
    canvas.clipRect(Offset.zero & size);
    for (final batch in _batches) {
      batch.length = 0;
    }

    // Convert the unit cylinder into pixels while fitting the available area.
    final radius = math.min(size.width * 0.405, size.height * 0.35);
    final center = Offset(size.width / 2, size.height * 0.48);
    final cosTilt = math.cos(scene.tilt);
    final sinTilt = math.sin(scene.tilt);
    // At the default view: +1 is clockwise, -1 is anticlockwise.
    const rotationDirection = -1.0;
    // Both arrows share the same movement and drag offset.
    final sharedAngle = rotationDirection * scene.rotation + scene.orbit + 0.3;

    // Violet stays exactly half a turn away from gold.
    final rotations = <double>[sharedAngle, sharedAngle + math.pi];

    // // The minus sign makes violet rotate opposite to gold.
    // final rotations = <double>[
    //   scene.rotation + scene.orbit + 0.3,
    //   // π starts violet half a turn away; 0.3 sets the initial view angle.
    //   scene.rotation + scene.orbit + math.pi + 0.3,
    // ];
    // Compute shared trigonometry once per ribbon, not once per particle.
    final cosines = rotations.map(math.cos).toList();
    final sines = rotations.map(math.sin).toList();
    final springs = List.generate(RibbonScene.channelCount, scene.displacement);

    for (final particle in scene.particles) {
      final scatter = springs[particle.channel];
      // Rendered position = home position + scatter vector × spring value.
      final localX = particle.x + particle.scatterX * scatter;
      final localY = particle.y + particle.scatterY * scatter;
      // // Mirror violet's geometry so its arrowhead points the other way too.
      // final direction = particle.ribbon == 0 ? 1 : -1;
      // final localZ = (particle.z + particle.scatterZ * scatter) * direction;
      // Give both arrowhwads the same winding and match their travel direction.
      final localZ =
          (particle.z + particle.scatterZ * scatter) * rotationDirection;

      // Rotate around the vertical axis, then tilt toward the camera.
      final c = cosines[particle.ribbon];
      final s = sines[particle.ribbon];
      // Rotation mixes x and z while keeping the cylinder's vertical axis.
      final x = localX * c - localZ * s;
      final z = localX * s + localZ * c;
      // Tilt mixes height and depth to reveal the top or bottom of the circle.
      final yView = localY * cosTilt - z * sinTilt;
      final zView = localY * sinTilt + z * cosTilt;

      // Perspective division: points nearer the camera look larger.
      const cameraDistance = 6.0;
      // Clamp the denominator to keep extreme scatter positions finite.
      final perspective =
          cameraDistance / math.max(1.5, cameraDistance - zView);
      final screenX = center.dx + x * radius * perspective;
      final screenY = center.dy + yView * radius * perspective;
      // Map depth to 0–1 so nearer particles can shine more brightly.
      final depth = ((zView + 1.4) / 2.8).clamp(0.0, 1.0);
      final light = particle.edge
          ? 0.30 + depth * 0.70
          : (0.12 + depth * 0.88) * particle.brightness;
      // Particles with the same colour, edge type, and light share a draw call.
      final level = (light * (_levels - 1)).round();
      final group = particle.ribbon * 2 + (particle.edge ? 1 : 0);
      _batches[group * _levels + level].add(screenX, screenY);
    }

    // Keep dot sizes proportional when the available canvas size changes.
    final pointScale = (radius / 160).clamp(0.55, 1.5);
    for (var group = 0; group < 4; group++) {
      final color = group < 2 ? ribbonGold : ribbonViolet;
      final edge = group.isOdd;
      for (var level = 0; level < _levels; level++) {
        final batch = _batches[group * _levels + level];
        if (batch.length == 0) continue;
        final points = batch.points;
        final light = level / (_levels - 1);
        if (edge) {
          // Wide, faint dots create a halo without expensive blur passes.
          _paint
            ..color = color.withValues(alpha: 0.012 + light * 0.025)
            ..strokeWidth = 6.0 * pointScale;
          canvas.drawRawPoints(ui.PointMode.points, points, _paint);
          _paint
            ..color = color.withValues(alpha: 0.035 + light * 0.075)
            ..strokeWidth = 3.0 * pointScale;
          canvas.drawRawPoints(ui.PointMode.points, points, _paint);
        }
        // A smaller, brighter point forms the crisp centre of each particle.
        _paint
          ..color = color.withValues(
            alpha: edge ? 0.20 + light * 0.70 : 0.035 + light * 0.50,
          )
          ..strokeWidth = (edge ? 1.20 : 0.90) * pointScale;
        canvas.drawRawPoints(ui.PointMode.points, points, _paint);
      }
    }
    // Restore the canvas so our clipping does not affect other widgets.
    canvas.restore();
  }

  /// A replacement painter needs repainting only when its scene changes.
  @override
  bool shouldRepaint(covariant RibbonPainter oldDelegate) {
    return oldDelegate.scene != scene;
  }
}

/// Reuses a flat `x, y, x, y, ...` buffer for one particle drawing group.
class _PointBatch {
  /// Reserves two float values for each possible particle in this group.
  _PointBatch(int capacity) : _coordinates = Float32List(capacity * 2);

  final Float32List _coordinates;
  // Number of float values in use, rather than number of particles.
  int length = 0;

  /// Appends one projected 2D point to the reused buffer.
  void add(double x, double y) {
    _coordinates[length++] = x;
    _coordinates[length++] = y;
  }

  /// Exposes just the populated coordinates without copying the buffer.
  Float32List get points => Float32List.sublistView(_coordinates, 0, length);
}
