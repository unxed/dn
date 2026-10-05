# Class migration

Both repositories are worked on directly in `main`. Every commit is pushed to
GitHub immediately after it is created.

## Required gates

- The class-migrated TV3 tree has a case-insensitive whole-tree scan for
  `obj[e]ct`, including ignored files and binary build caches; Git metadata is
  excluded. Keep compiler output outside the scanned tree.
- Before DN class-migration acceptance, search the complete tree case-insensitively
  for `object`, including ignored files and generated/binary files, and inspect
  every match. No Pascal `object`-dialect construction may remain anywhere.
- Audit the complete DN tree case-insensitively for the substring `object` and
  inspect every match. No Pascal `object`-dialect construction may remain in
  any file. Hard textual sub-gate: zero `object` substring matches in Pascal
  source files (`.pas`, `.pp`, `.inc`, and other Pascal compilation units),
  including comments and string literals; remove incidental mentions there
  too. Review non-Pascal matches and classify them as documentation, test
  fixtures, generated output, or genuine migration residue. Keep compiler
  products/caches outside the tree when they would otherwise create hits.
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
   before the migration is accepted as complete.

## Remaining implementation work

- Remove class-reference aliases in tv3 and DN and update their consumers.
- Complete construction, destruction, direct member access and overrides in DN.
- Replace resource retyping with subclass construction by the resource loader.
- Bring the complete DN tree through its spelling gate, including build output.
- Complete the case-insensitive whole-tree `object` audit; remove all
  Pascal-source matches and verify that no legacy Pascal object-dialect
  constructs remain elsewhere in the tree.
- Verify native and DOS tv3 checks, then the supported DN builds, full
  object/class parity and runtime tests.
- Publish only to `main`; the previous branch/PR integration step has already
  been completed and is not part of the remaining work.

The `class-migration` workflow checks the current focused regression tests.
It supplements the full workflows and does not waive either final tree gate.
