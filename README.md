# Yesteryear

An interactive Star Trek story from Third Moon Interactive, built on the Vulcan Fury framework.

## What's here so far

| Piece | Where | Notes |
|---|---|---|
| Guardian of Forever | `scenes/guardian/Guardian.tscn` | Drop-in scene. Doorway centred on the origin, floor at ground level, walk through along Z. About 5.5 m wide, 3.8 m tall, doorway about 2.7 m high. Collision is built automatically on import. |
| Guardian model | `assets/models/guardian/guardian_of_forever.glb` | Cleaned up from the "Guardian of Forever Gate and Base" 3D-print kit: the two print halves rejoined, the joining pegs removed, the display plinth left out. ~77k triangles; Godot makes the lighter distance versions itself on import. |
| Guardian stone | `assets/materials/guardian_stone.tres` | Rock texture wrapped on from all sides (the print model has no texture layout). Uses the Vulcan desert rock textures. |
| Ruins | `assets/models/ruins/` | Arch, curved and long colonnades, gatehouse, temple corner, copied from Vulcan Fury's desert ruins. |
| Column | `assets/models/column/` | Single column from Vulcan Fury's colony pack. |
| Tools | `tools/` | The scripts used to rebuild the Guardian from the print file. |
