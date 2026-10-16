# Particle Ribbons

A Flutter recreation of the gold and violet particle arrows in the reference
clip. Everything is drawn live with Flutter's canvas, with no video assets or
external runtime dependencies.

## Run

```sh
flutter devices
flutter run --profile -d <device-id>
```

Drag the scene to orbit. Tap it or press **Scatter** to disperse the particles.
The pause button freezes rotation and the springs. **Physics** opens controls
for rotation speed, spring stiffness, and damping.

## How it works

1. **Shape:** Sample 6,000 points inside a flat arrow and 1,600 along its outline.
   Do this for each colour: 15,200 particles total.
2. **Wrap:** Treat the arrow's horizontal coordinate as an angle around a
   cylinder. `x = r * cos(angle)`, `z = r * sin(angle)`, and `y` is its height.
3. **Move:** Rotate the two ribbons in opposite directions using elapsed time.
   A separate orbit responds to dragging, with decaying momentum after release.
4. **Project:** Tilt the coordinates toward the camera, then apply perspective
   division to turn each 3D point into a 2D position. Depth affects brightness.
5. **Draw:** Batch points by colour, outline/surface, and brightness into reused
   typed buffers. Draw luminous outlines with a soft halo and additive blending.
   The painter listens directly to the model, avoiding widget layout each frame.

## The spring

Each particle has a permanent home on its ribbon and a seeded scatter vector.
Its position is `home + scatterVector * springDisplacement`. Flutter's analytic
`SpringSimulation` solves the damped spring equation:

```text
F = -k*x - c*v
mass * acceleration = force
```

Stiffness `k` pulls toward home, damping `c` removes energy, and velocity `v`
carries particles past rest. Mass is fixed at 1. Twelve response groups have
slightly different stiffnesses, so particles return at different rates without
requiring a simulation object for every particle. Another scatter preserves
current spring positions and adds velocity; retuning preserves both position
and velocity. This is an artistic particle model with no collisions.

Start with [the model](lib/animation/ribbon_scene.dart), then read
[the painter](lib/animation/ribbon_painter.dart). The interface and display ticker
are in [main.dart](lib/main.dart).

## Verify

```sh
flutter analyze
flutter test
```

Tests cover spring convergence, interruption, pause/reset, particle geometry,
touch controls, and a compact landscape layout. Measure rendering performance
in profile mode on the target device.
