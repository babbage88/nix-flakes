#!/usr/bin/env sh
NIXSRCDIR="$HOME/projects/nix-flakes/rockydev2.homemgr"
HMDIR="$HOME/.config/home-manager"
NIXHOMECFG="$NIXSRCDIR/home.nix"
export FLAKEKEY="$HMDIR/#jtrahan"
printf "copying %s to %s...\n" "$NIXHOMECFG" "$HMDIR"
cp home.nix $HMDIR/home.nix
printf "copying flake files to %s...\n" "$HMDIR"
cp flake.* $HMDIR/
printf "rebuild nix hm config: %s...\n" "$FLAKEKEY"
home-manager switch --flake $FLAKEKEY -b backup
