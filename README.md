## 🧾 Instructions

0. **Pre-requisites**
   - Docker must be installed. This is used to run a martin tile server image, which is the one that converts source files to sprites.
   - Python 3 must be installed. It's used by `scripts/round_svg_numbers.py` (see step 2 below) and by `generate_sprites.sh`, which uses `scripts/strip_stretchable_markers.py` to strip the stretchable-icon marker fills (`content`/`stretchX`/`stretchY`) out of the SVGs before martin sees them. No extra packages needed - both only use the standard library.

1. **Make sure that the assets in `sprite_assets` are correct.**  
   It is essential that the file names are correct.  
   For each folder (= OMS partner), there should be two folders – `light` and `dark`. Then follow the same patterns as used in the app.
   Remember - all svgs should have a theme suffix -> `light` or `dark`.

2. **Round the SVGs before committing.**
   Figma re-exports the same, unchanged design with slightly different floating point noise every time (e.g. `20.4598` one export, `20.4594` the next), which makes every touched SVG show up as modified even when nothing actually changed. Run this after exporting from Figma and before committing:
   ```sh
   python3 scripts/round_svg_numbers.py sprite_assets
   ```
   This rounds every numeric value (path data, coordinates, transforms, ...) to 2 decimal places directly in the SVG files - well below one pixel at these icon sizes, so it has no visible effect, but it means two exports of the same design produce an identical diff-free file. Files that need no changes are left untouched.

3. **Generate sprites**
   ```sh
   bash generate_sprites.sh
   ```
   After the run completes, the updated sprites should be available inside the `generated_sprites` folder.

   You can also pass one or more namespace names to only regenerate specific orgs:
   ```sh
   bash generate_sprites.sh AtB FRAM
   ```

> **CI:** When a pull request touches files under `sprite_assets/` or `scripts/`, GitHub Actions runs the script tests, then (if `sprite_assets/` changed) regenerates sprites for the changed namespaces and commits the result back to the PR branch. No manual script run needed.

   **Running the script tests locally:**
   ```sh
   python3 -m unittest discover scripts
   ```

4. **Upload sprites to GCS**

   Pre-requisites:
   - `gcloud` CLI installed and authenticated: `gcloud auth application-default login`
   - Your account needs `roles/storage.objectAdmin` on the target `*--shared-assets` buckets.

   ```sh
   bash upload_sprites.sh staging   # upload to all staging buckets
   bash upload_sprites.sh prod      # upload to all prod buckets
   ```

   Each run:
   - Bumps the version automatically (reads last version from `uploads.md`, increments)
   - Uploads all four tenants (AtB, Troms, NFK, FRAM) to the new `vN` path in their respective GCS buckets
   - Commits the new `uploads.md` row and pushes an annotated git tag `upload/<env>/v<N>`

   After uploading, open a PR in `firestore-configuration` to point the `mapboxSpriteUrls` for the relevant tenants at the new version path.
