## 🧾 Instructions

0. **Pre-requisites**
   Docker must be installed. This is used to run a martin tile server image, which is the one that converts source files to sprites.

1. **Make sure that the assets in `sprite_assets` are correct.**  
   It is essential that the file names are correct.  
   For each folder (= OMS partner), there should be two folders – `light` and `dark`. Then follow the same patterns as used in the app.
   Remember - all svgs should have a theme suffix -> `light` or `dark`.

2. **Generate sprites**
   ```sh
   bash generate_sprites.sh
   ```
   After the run completes, the updated sprites should be available inside the `generated_sprites` folder.

   You can also pass one or more namespace names to only regenerate specific orgs:
   ```sh
   bash generate_sprites.sh AtB FRAM
   ```

> **CI:** When a pull request touches files under `sprite_assets/`, GitHub Actions automatically regenerates sprites for the changed namespaces and commits the result back to the PR branch. No manual script run needed.
