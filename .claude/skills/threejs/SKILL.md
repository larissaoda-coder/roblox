---
name: threejs
description: Write, fix and explain three.js code (JavaScript 3D on the web, using WebGLRenderer, WebGPURenderer, TSL node shaders, GLTF loading, materials, lights, cameras, controls and post-processing) with the official three.js r186 docs for LLMs. Use whenever a task touches three.js or `three` imports, a 3D web scene, a WebGL/WebGPU canvas, or TSL/NodeMaterial shaders. Not for the Roblox/Luau code in this repository.
---

# three.js

Built from the official LLM docs in [mrdoob/three.js](https://github.com/mrdoob/three.js)
(`docs/llms.txt` and `docs/llms-full.txt`), snapshot **r186 / `three@0.186.0`**.

## Before writing code

1. **Pin the version.** If the project has `three` in `package.json`, read the installed
   version (`node_modules/three/package.json` or the lockfile) and follow that API.
   For a standalone page, use `0.186.0` as in the snippets below.
2. **Look APIs up instead of recalling them.** three.js renames and deprecates often, so
   confirm any class or option you are unsure of (see "Looking things up").

## Official rules

### 1. ES modules + import maps (never the old CDN global)

Wrong (outdated): `<script src=".../three.js/r128/three.min.js"></script>` and a global `THREE`.

```html
<script type="importmap">
{
  "imports": {
    "three": "https://cdn.jsdelivr.net/npm/three@0.186.0/build/three.module.js",
    "three/addons/": "https://cdn.jsdelivr.net/npm/three@0.186.0/examples/jsm/"
  }
}
</script>
<script type="module">
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
</script>
```

With npm and a bundler: `npm install three`, then the same `import` lines. Addons always come
from `three/addons/...` (the old `examples/js` globals no longer exist).

### 2. WebGLRenderer or WebGPURenderer

- **WebGLRenderer** is the default. It is mature, has the widest browser support, and most
  examples use it.
  ```js
  import * as THREE from 'three';
  const renderer = new THREE.WebGLRenderer( { antialias: true } );
  ```
- **WebGPURenderer** is for custom shaders/materials in TSL, compute shaders, and node-based
  materials. Import from `three/webgpu` and await `init()`:
  ```js
  import * as THREE from 'three/webgpu';
  const renderer = new THREE.WebGPURenderer();
  await renderer.init();
  ```
  Import map for WebGPU: `"three"` maps to `.../build/three.webgpu.js` and `"three/tsl"` maps
  to `.../build/three.tsl.js` (full page in `references/llms-full.txt`, section
  "Basic Scene with WebGPURenderer and TSL").

### 3. TSL instead of GLSL strings

With WebGPURenderer, write custom materials in TSL (Three.js Shading Language), not raw GLSL,
`ShaderMaterial` strings or `onBeforeCompile` hacks. TSL compiles to both the WebGPU and the
WebGL backends.

```js
import { texture, color } from 'three/tsl';

const material = new THREE.MeshStandardNodeMaterial();
material.colorNode = texture( myTexture ).mul( color( 0xff0000 ) );
```

Use the node material classes: `MeshBasicNodeMaterial`, `MeshStandardNodeMaterial`,
`MeshPhysicalNodeMaterial`, `LineBasicNodeMaterial`, `SpriteNodeMaterial`.

## Current-API checklist

- Drive frames with `renderer.setAnimationLoop( animate )`, not a hand-rolled
  `requestAnimationFrame` loop (WebXR requires it).
- Use `THREE.Timer` for time. `THREE.Clock` has been deprecated since r183. Call
  `timer.update( timestamp )` at the top of each frame, then `timer.getDelta()` or
  `timer.getElapsed()`. `timer.connect( document )` pauses it while the tab is hidden.
- Use `BufferGeometry` only. The legacy `Geometry` class is gone.
- Color management is on by default and `renderer.outputColorSpace` defaults to
  `SRGBColorSpace`. Set `texture.colorSpace = THREE.SRGBColorSpace` on color/albedo textures
  you load yourself (`GLTFLoader` already does this). Leave data maps (normal, roughness,
  metalness, AO) at their default.
- Lights use physical units, and `physicallyCorrectLights` / `useLegacyLights` no longer
  exist. When ported code looks dark, raise the light intensities. Don't look for the flag.
- On resize, update `camera.aspect`, call `camera.updateProjectionMatrix()`, then
  `renderer.setSize( w, h )`. Use `renderer.setPixelRatio( Math.min( devicePixelRatio, 2 ) )`
  to keep fill rate in check.
- `scene.remove()` does not free GPU memory. Call `.dispose()` on geometries, materials and
  textures you discard, and on the renderer when tearing the canvas down.
- For many copies of one mesh, use `InstancedMesh`. For many different geometries that share
  a material, use `BatchedMesh`.

## Looking things up

| Source | Use it for |
|---|---|
| `references/llms.txt` | Short official index: the rules above plus links to manual pages (installation, fundamentals, scene graph, materials, textures, lights, cameras, shadows, animation, loading models). |
| `references/llms-full.txt` | About 8,250 lines. **Grep it; don't read the whole thing.** See the map below. |
| `https://threejs.org/docs/pages/{Name}.html.md` | Markdown API page for one class, e.g. `.../GLTFLoader.html.md`, `.../InstancedMesh.html.md`. |
| `node_modules/three/src/`, `node_modules/three/examples/jsm/` | The actual source. Its JSDoc is what the API pages are generated from. Use it when threejs.org is unreachable or to confirm a signature for the installed version. |
| GitHub `mrdoob/three.js`: `examples/*.html` | Official working demos for nearly every feature (the `webgpu_*` files show TSL usage). |

Map of `references/llms-full.txt` (find a section with
`grep -n '^## <Heading>' .claude/skills/threejs/references/llms-full.txt`, then read from
that line):

- `## Complete Code Examples`: a full WebGLRenderer page, a full WebGPURenderer + TSL page,
  and GLTF loading.
- `# TSL (Three.js Shading Language) - Complete Reference`: one `## ` heading per topic.
  Syntax: Node Material, Method Chaining, Swizzle, Constants and Conversions, Operators,
  Math, Function, Assignments, Variables, Uniform, Array, Struct, If-Else, Loop.
  Stages: Vertex Stage and Varying, Compute Stage, Storage, Atomic.
  Inputs: Attributes, Texture, Position, Normal, Camera, Screen.
  Lighting and scene: Lights, Shadows, Fog, Background.
  Render pipeline: Pass, MRT, Post-Processing, RTT.
  Utilities: Timer, Oscillator, UV, Random, Noise, Blend Modes.
  Interop: Transpiler, WGSL (`wgslFn`), GLSL (`glslFn` and the "GLSL to TSL Mapping" table).
- `## Available Documentation`: an index of every API page, grouped under `### Core`,
  `Cameras`, `Lights`, `Materials`, `Geometries`, `Textures`, `Loaders`, `Controls`,
  `Helpers`, `Animation`, `Audio`, `Math`, `Curves`, `Effects`, `Post-Processing`,
  `Nodes (TSL)`, `WebXR` and `Shader Modules`. Use it to find a class's exact name before
  fetching its page.

## Updating this skill

`references/llms.txt` and `references/llms-full.txt` are verbatim copies of `docs/llms.txt`
and `docs/llms-full.txt` from the `dev` branch of mrdoob/three.js. Upstream generates them
with `utils/llms/build.js`. To refresh, copy the new files over the old ones and replace
`0.186.0` / `r186` in this file with the new version.

three.js is MIT licensed. See `references/LICENSE`.
