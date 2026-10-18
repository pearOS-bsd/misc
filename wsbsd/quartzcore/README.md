# QuartzCore (Core Animation) for FreeBSD

An implementation of Core Animation with the behaviour of Apple's: `CALayer` (model and presentation layers, implicit actions, geometry), the animation classes (basic, keyframe, spring, group, transition), timing functions, `CATransaction`, the layer subclasses (shape, text, gradient, replicator, transform, scroll), `CAFilter`, and a software compositor (`CARenderer`, `CARenderPresentation`).

## How it is checked

Apple's QuartzCore on a Mac is the reference. The same scenarios run against it and against this library:

| target | what it compares |
|---|---|
| `make check-golden` | animation values sampled over time (1307 lines) |
| `make check-actions` | which implicit animations a property change creates |
| `make check-values` | interpolation, key paths, value functions |
| `make check-fuzz` / `check-defaults` | random animations, default property values |
| `make render-compare` | scenes rendered by `CARenderer` and by this compositor, per-pixel error (macOS only) |
| `make check-ref` | the same scenarios against reference output recorded from Apple's QuartzCore (`test/ref`), runs on FreeBSD and in CI |
| `make bench` | timings |

Filters (`CAFilter`: gaussian blur, saturate, brightness, contrast, colour matrix, invert, multiply) are applied to a layer's group (`filters`) or to what is behind it (`backgroundFilters`). Colour filters match `CARenderer` exactly, blur inside the content matches to a mean error of 0.3 of 255. Known gap: a backdrop blur differs from Apple's within a few pixels of the canvas edge.

## Benchmarks (`make bench`, Apple M-series, one core)

```
== Core Animation benchmarks ==
basic animation (ease in/out) applied:   2346690 /s  (0.43 us each)
spring animation applied:                2251704 /s  (0.44 us each)
layers created and added:                 609493 /s
presentation of 2000 animated layers:       2.14 ms per frame
compositor 1280x800, 3 windows           8.9 ms per frame  (112.6 fps)
compositor 1920x1080, 3 windows          9.2 ms per frame  (109.3 fps)
compositor 1920x1080, 6 windows         17.6 ms per frame  ( 56.8 fps)
```

## AppKit

`sdk/src/AppKitLayers.m` gives GNUstep's `NSView` `wantsLayer` / `layer` / `makeBackingLayer`; the topmost layer-backed view renders the layer tree with its animations. `sdk/src/AppKitAnimation.m` gives `NSAnimationContext` and the `animator` proxies, on the curves of Core Animation. `sdk/tests/layer_demo.m` is a demo and self-test.

## Not done yet

Rendering of `CATransition`, emitter and tiled layers; 3D matrix interpolation (`mat4` mix is a placeholder); arc-length parametrisation of paced path animations (about 0.3 px off).
