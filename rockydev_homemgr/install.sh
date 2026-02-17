#!/usr/bin/env sh
NIXSRCDIR="$HOME/projects/nix-flakes/rockydev_homemgr"
HMDIR="$HOME/.config/home-manager"
NIXHOMECFG="$NIXSRCDIR/home.nix"
export FLAKEKEY="$HMDIR/#jtrahan"

##### ANSI Color Codes #####
C_B_RED='\033[31;1m'
C_B_GREEN='\033[32;1m'
C_B_YELLOW='\033[33;1m'
C_B_BLUE='\033[34;1m'
C_B_CYAN='\033[36;1m'
C_B_WHITE='\033[37;1m'

C_RED='\033[31m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_BLUE='\033[34m'
C_CYAN='\033[36m'
BOLD_WHITE='\033[01;97m'
BOLD_GREEN='\033[01;96m'
BOLD_BLUE='\033[01;94m'
BOLD_YELLOW='\033[01;93m'
BOLD_RED='\033[01;92m'
C_RESET='\033[0m'

install_hm() {
	local srcdir=${1:-$NIXSRCDIR}
	local dsthomedir=${2:-$HMDIR}
	local src_hm_cfg=${3:-$NIXHOMECFG}

	mkdir -p $dsthomedir
	printf "${BOLD_WHITE}copying %s to %s...\\n${C_RESET}" "$src_hm_cfg" "$dsthomedir"
	cp $src_hm_cfg $dsthomedir/home.nix
	printf "${BOLD_WHITE}copying flake files to${C_CYAN} %s${BOLD_WHITE}...\\n${C_RESET}" "$dsthomedir"
	cp $srcdir/flake.* $dsthomedir/
}

update_nixpkg() {
	local dsthomedir=${1:-$HMDIR}
	local flake_key="$dsthomedir/#$USER"
	export FLAKEKEY=$flake_key
	local cur_dir_start=$(pwd)
	printf "${BOLD_WHITE}cd into home-manager install dir %s...\\n${C_RESET}" "$dsthomedir"
	cd $dsthomedir
	printf "${BOLD_WHITE}Updating nix channels...${C_RESET}\\n"
	nix-channel --update
	printf "${BOLD_WHITE}Updating nix ${C_B_CYAN}flake.lock${BOLD_WHITE} file...${C_RESET}\\n"
	nix flake update
	printf "${BOLD_WHITE}switching home-manager to flake:${C_B_GREEN} %s\\n${C_RESET}" "$flake_key"
	home-manager switch --flake $flake_key
	printf "${BOLD_WHITE}completed${C_GREEN}flake_key: ${C_B_GREEN}${flake_key}${C_RESET}\\n"
	printf "${BOLD_WHITE}changing directory back to the starting dir:${C_B_BLUE} %s\\n${C_RESET}" "$cur_dir_start"
	cd $cur_dir_start
}

hm_switch() {
	local dsthomedir=${1:-$HMDIR}
	local flake_key="$dsthomedir/#$USER"
	local cur_dir_start=$(pwd)

	export FLAKEKEY=$flake_key
	echo "${BOLD_WHITE}flake key is: ${C_B_GREEN}$FLAKEKEY${C_RESET}"
	printf "${BOLD_WHITE}cd into home-manager install dir ${C_B_YELLOW}%s...\\n${C_RESET}" "$dsthomedir"
	cd $dsthomedir
	printf "${BOLD_WHITE}switching home-manager to ${C_B_GREEN}flake: %s\\n${C_RESET}" "$flake_key"
	home-manager switch --flake $flake_key
	printf "${BOLD_WHITE}changing directory back to the starting dir:${C_B_BLUE} %s\\n${C_RESET}" "$cur_dir_start"
	cd $cur_dir_start
}

install_and_updatepkg() {
	install_hm && update_nixpkg && hm_switch
}

install_and_updatepkg
#hm_switch
#install_hm
