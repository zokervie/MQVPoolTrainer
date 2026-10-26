# Exact upstream source map
Repository: https://github.com/zokervie/MQVPoolTrainer
Pinned revision: 555af3c76916607bddc931da68dff81f0ab47963

**Files here named *-extract.js contain only verified excerpts; they do NOT contain entire upstream files.** Fetch source originals using the links below before integrating.

| Role | Exact upstream file |
|---|---|
| Web visual rendering (Three.js) | https://github.com/zokervie/MQVPoolTrainer/blob/555af3c76916607bddc931da68dff81f0ab47963/src/render.js |
| Table geometry / diamonds / pocket jaws | https://github.com/zokervie/MQVPoolTrainer/blob/555af3c76916607bddc931da68dff81f0ab47963/src/table.js |
| Web physics and rail collisions | https://github.com/zokervie/MQVPoolTrainer/blob/555af3c76916607bddc931da68dff81f0ab47963/src/physics.js |
| Native iOS 3D rendering SceneKit | https://github.com/zokervie/MQVPoolTrainer/blob/555af3c76916607bddc931da68dff81f0ab47963/ios/PoolTrainer/Scene/PoolScene.swift |
| Native iOS material & textures | https://github.com/zokervie/MQVPoolTrainer/blob/555af3c76916607bddc931da68dff81f0ab47963/ios/PoolTrainer/Scene/Textures.swift |
| Native touch / power / effect UI | https://github.com/zokervie/MQVPoolTrainer/blob/555af3c76916607bddc931da68dff81f0ab47963/ios/PoolTrainer/UI/Controls.swift |
| Native iOS table view | https://github.com/zokervie/MQVPoolTrainer/blob/555af3c76916607bddc931da68dff81f0ab47963/ios/PoolTrainer/UI/TableView.swift |
| Native physics | https://github.com/zokervie/MQVPoolTrainer/blob/555af3c76916607bddc931da68dff81f0ab47963/ios/PoolTrainer/Core/Physics.swift |
| Table brand / calibration data | https://github.com/zokervie/MQVPoolTrainer/blob/555af3c76916607bddc931da68dff81f0ab47963/ios/PoolTrainer/Core/TableSpecs.swift |
| Shot analysis | https://github.com/zokervie/MQVPoolTrainer/blob/555af3c76916607bddc931da68dff81f0ab47963/ios/PoolTrainer/Core/ShotAnalysis.swift |
| Existing physics tests | https://github.com/zokervie/MQVPoolTrainer/blob/555af3c76916607bddc931da68dff81f0ab47963/test/physics.test.js |
| Original physics spec | https://github.com/zokervie/MQVPoolTrainer/blob/555af3c76916607bddc931da68dff81f0ab47963/ios/docs/dac-ta/01-physics.md |

Secondary source (distinct codebase and early revision): https://github.com/zokervie/Zoker-Pool-Trainer/tree/a5fc93fd4430b1c4a15266c07fff79d7175823b2
Its `Packages/PoolPhysics` + `Packages/PoolInput` are NOT the same source structure as the repo above. Avoid silently mixing their types or algorithms.
