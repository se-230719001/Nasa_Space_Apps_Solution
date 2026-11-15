// Decodes a Draco-compressed glTF (KHR_draco_mesh_compression) so Godot can
// import it. Nothing else is changed: same meshes, materials, textures, animations.
// Needs @gltf-transform/core, @gltf-transform/extensions and draco3dgltf next to
// this file (build_nasa_db.py copies it into the folder where they are installed).
// Usage: node undraco.mjs in.glb out.glb
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import draco3d from 'draco3dgltf';

const io = new NodeIO()
	.registerExtensions(ALL_EXTENSIONS)
	.registerDependencies({ 'draco3d.decoder': await draco3d.createDecoderModule() });
const doc = await io.read(process.argv[2]);
for (const ext of doc.getRoot().listExtensionsUsed()) {
	if (ext.extensionName === 'KHR_draco_mesh_compression') ext.dispose();
}
await io.write(process.argv[3], doc);
