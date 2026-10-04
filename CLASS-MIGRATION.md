# Class migration

Work stays in `classes/tv-classes` in tv3 and `classes/tv3-dependency` in DN.
DN is integrated through one PR after the migration passes its final checks.
Every commit is pushed immediately to its corresponding GitHub branch.

## Required gates

- Before changing DN, run `tv/tools/class-gate.sh` against its pinned tv3 checkout.
  It must report no case-insensitive matches for `obj[e]ct` in the whole working
  tree, including ignored files and binary build caches. Git metadata is excluded.
- DN must satisfy the same whole-tree condition before merging. Scanning tracked
  text alone is insufficient. Compiler output belongs outside the scanned source tree.
- Classes use their semantic `T...` names, direct member access, `Create`, `Destroy`
  and `Free` or `FreeAndNil`. An alias carrying an old pointer/type name is not a
  completed migration. Actual pointers to records and scalar data remain pointers.
- Overridden methods must dispatch through the inherited class API. Resource
  loading must construct the required subclass; changing an instance's VMT is
  not an acceptable final implementation.
- Preserve ownership, stream compatibility, behaviour and supported platforms.
  Passing a focused check does not prove the entire application is ready.

## Editing and verification

1. Save and publish the current state before a regular expression or another
   potentially destructive bulk rewrite. Record the exact checkpoint SHA.
2. If a rewrite gives incorrect results, roll back the whole affected batch to
   that checkpoint. Reapply sound transformations from the original source.
   Never repair the individual consequences of the failed rewrite.
3. For every successfully converted pattern, check whether one script can cover
   all semantically equivalent uses across the active sources. Keep record
   pointers, strings and comments distinct from class references.
4. Make small atomic changes, from simple class APIs to more complex ownership
   and loading paths. Run meaningful checks for each change and push its commit.
5. After each ten fixes, review how to improve efficiency: batch recurring
   transformations, improve the conversion tool, and remove redundant checks.
6. GitHub Actions results are authoritative only for their exact commit and a
   terminal successful run. Required full builds and runtime checks must pass
   before either migration branch is merged.

## Remaining implementation work

- Remove class-reference aliases in tv3 and DN and update their consumers.
- Complete construction, destruction, direct member access and overrides in DN.
- Replace resource retyping with subclass construction by the resource loader.
- Bring the complete DN tree through its spelling gate, including build output.
- Verify native and DOS tv3 checks, then the supported DN builds and runtime tests.
- Merge tv3, update the reviewed DN dependency pin, and merge the single DN PR.

The `class-migration` workflow checks the current focused regression tests.
It supplements the full workflows and does not waive either final tree gate.
