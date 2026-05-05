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

3. **Upload sprites to GCS**

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
