#!/usr/bin/env sh
NIXSRCDIR="$HOME/projects/nix-flakes/rockydev_homemgr"
HMDIR="$HOME/.config/home-manager"
NIXHOMECFG="$NIXSRCDIR/home.nix"
export FLAKEKEY="$HMDIR/#jtrahan"

install_hm() {
	local srcdir=${0:-$NIXSRCDIR}
	local dsthomedir=${1:-$HMDIR}
	local src_hm_cfg=${2:-$NIXHOMECFG}
	export FLAKEKEY="$dsthomedir/#$USER"

	mkdir -p $dsthomedir
	printf "copying %s to %s...\n" "$src_hm_cfg" "$dsthomedir"
	cp $src_hm_cfg $dsthomedir/home.nix
	printf "copying flake files to %s...\n" "$dsthomedir"
	cp $srcdir/flake.* $dsthomedir/
	printf "rebuild nix hm config: %s...\n" "$FLAKEKEY"
	home-manager switch --flake $FLAKEKEY -b backup
}

update_nixpkg() {
	local dsthomedir=${0:-$HMDIR}
	local flake_key="$dsthomedir/#$USER"
	local cur_dir_start=$(pwd)
	printf "cd into home-manager install dir %s...\n" "$dsthomedir"
	cd $dsthomedir
	printf "Updating cix channels...\n"
	nix-channel --update
	printf "Updating nix flake.lock file...\n"
	nix flake update
	printf "switching home-manager to flake: %s\n" "$flake_key"
	#home-manager switch --flake $flake_key
	echo $flake_key
	printf "changing directory back to the starting dir... %s\n" "$cur_dir_start"
	cd $cur_dir_start
}

hm_switch() {
	local dsthomedir=$HMDIR
	local flake_key="$dsthomedir/#$USER"
	local cur_dir_start=$(pwd)

	export FLAKEKEY=$flake_key
	echo "flake key is: $FLAKEKEY"
	printf "cd into home-manager install dir %s...\n" "$dsthomedir"
	cd $dsthomedir
	printf "switching home-manager to flake: %s\n" "$flake_key"
	home-manager switch --flake $flake_key
	printf "changing directory back to the starting dir... %s\n" "$cur_dir_start"
	cd $cur_dir_start
}
hm_switch
#install_hm
