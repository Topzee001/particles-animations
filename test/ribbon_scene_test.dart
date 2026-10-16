import 'package:exp_anim/animation/ribbon_scene.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checks particle generation and spring behaviour without launching the app.
void main() {
  late RibbonScene scene;

  setUp(() => scene = RibbonScene());
  tearDown(() => scene.dispose());

  // Advance a repeatable simulation clock without waiting for real time.
  void advanceFor(double seconds) {
    for (var i = 0; i < (seconds * 120).ceil(); i++) {
      scene.advance(1 / 120);
    }
  }

  test('Both ribbons contain finite surface and outline particles', () {
    expect(scene.particles.length, 15200);
    for (var ribbon = 0; ribbon < 2; ribbon++) {
      final particles = scene.particles.where((p) => p.ribbon == ribbon);
      expect(particles.where((p) => p.edge).length, 1600);
      expect(particles.where((p) => !p.edge).length, 6000);
      for (final p in particles) {
        expect(p.x.isFinite && p.y.isFinite && p.z.isFinite, isTrue);
        expect(p.x * p.x + p.z * p.z, closeTo(1, 0.02));
      }
    }
  });

  test('Scattering displaces particles and springs return exactly home', () {
    scene.scatter();
    advanceFor(0.2);
    expect(scene.displacement(0), greaterThan(0.1));
    expect(scene.isScattered, isTrue);
    advanceFor(5);
    expect(scene.isScattered, isFalse);
    for (var i = 0; i < RibbonScene.channelCount; i++) {
      expect(scene.displacement(i), 0);
    }
  });

  test('Interrupted and retuned springs remain continuous and settle', () {
    scene.scatter();
    advanceFor(0.1);
    final before = scene.displacement(0);
    scene.scatter();
    expect(scene.displacement(0), before);
    scene.tune(stiffness: 95, damping: 12);
    expect(scene.displacement(0), before);
    advanceFor(5);
    expect(scene.isScattered, isFalse);
  });

  test('Pause freezes the simulation and reset restores the experiment', () {
    scene.scatter();
    advanceFor(0.2);
    scene.togglePlaying();
    final time = scene.time;
    final displacement = scene.displacement(0);
    advanceFor(1);
    expect(scene.time, time);
    expect(scene.displacement(0), displacement);
    scene.reset();
    expect(scene.time, 0);
    expect(scene.isScattered, isFalse);
    expect(scene.playing, isTrue);
  });

  test('Changing rotation speed preserves the current orientation', () {
    advanceFor(2);
    final before = scene.rotation;
    scene.tune(speed: 0);
    advanceFor(1);
    expect(scene.rotation, before);
    scene.tune(speed: 1);
    advanceFor(1);
    expect(scene.rotation, closeTo(before + 1, 0.0001));
  });
}
