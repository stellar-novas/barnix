# BARnix

A Beyond All Reason build for nix.

Still roughing this out, but it should work for you.

## Usage

```sh
nix run --no-write-lock-file https://codeberg.org/jcdickinson/barnix/archive/main.tar.gz#byar
```

No launcher required, nix _is_ the launcher.

## TODO

- Needs some refactoring, almost everything is in the flake.nix
- Move version, rev, and SHA out of the flake.nix so that it can be easily changed by a script.
- Automatically update version/rev/SHA when anything changes on github.com/beyond-all-reason/
- Possibly make a script that includes the above usage
- Figure out how to split downloads into smaller units, so that delta updates can be done.
  I already attempted to use `fetchurl` for each file in `pool`, but nix would take a few seconds per patch of 32k.
  derivations. There are some 75000 files to download. Maybe we can put them into smaller chunks of files?
