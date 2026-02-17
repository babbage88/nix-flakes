{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "jtrahan";
  home.homeDirectory = "/home/jtrahan";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    pkgs.git 
    pkgs.gh 
    pkgs.minio-client
    pkgs.curl
    pkgs.wget 
    pkgs.goose 
    pkgs.sqlc 
    pkgs.nodejs_24
    pkgs.bun 
    pkgs.docker_29
    pkgs.kubectl
    pkgs.talosctl
    pkgs.kubernetes-helm
    pkgs.bat
    pkgs.neovim
    pkgs.btop
    pkgs.htop
    pkgs.go_1_26
    pkgs.shellcheck
    pkgs.javaPackages.compiler.openjdk25
    pkgs.bash
    pkgs.bundler.ruby
    pkgs.rustup
    pkgs.jq
    pkgs.yq-go
    pkgs.sqlite
    pkgs.postgresql_18
    pkgs.uv
    pkgs.dotnet-sdk_10
    pkgs.opentofu
    pkgs.libgcc
    pkgs.zig 
    pkgs.ansible 
    pkgs.gnumake
    pkgs.cobra-cli
    pkgs.fastfetch
    pkgs.bind
    pkgs.nmap
    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  home.file = {

    ### minio - helper func to gennerate minio key for the specified user defaults: devuser ###
    ".scripts/helper_funcs/minio_keys.sh" = {
        source = ./scripts/minio_keys.sh;
        executable = false;
    };

    ### nslookup_k8s - helper function to performing nslookup for kubernetes service ###
    ".scripts/helper_funcs/nslookup_k8s.sh" = {
        source = ./scripts/nslookup_k8s.sh;
        executable = false;
    };

    ### git related helper funcs ###
    ".scripts/helper_funcs/git_helpers.sh" = {
        source = ./scripts/git_helpers.sh;
        executable = false;
    };

    ### update-bind command for syncing dns via ansible playbook ###
    ".scripts/helper_funcs/update_bind.sh" = {
        source = ./scripts/update_bind.sh;
        executable = false;
    };

    ### ssh helper functions ###
    ".scripts/ssh_utils.sh" = {
      source = ./scripts/ssh_helpers.sh;
      executable = false;
    };


    ### nix home-manager helper funcs - install config from local git repo ###
    ".scripts/install_latest_nixhm.sh" = {
      source = ./install.sh;
      executable = true;
    };

    # Function to start an interactive shell in the specified pod
    ".scripts/helper_funcs/podterm.sh" = {
      source = ./scripts/podterm.sh;
      executable = false;
    };
    
    # Function to list pods on a specific node
    ".scripts/helper_funcs/nodepods.sh" = {
        source = ./scripts/nodepods.sh;
        executable = false;
    };
    
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/jtrahan/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "/usr/local/bin/nvim";
    GOPATH = "$HOME/go";
    GOBIN = "$HOME/go/bin";
  };

  programs.zsh = {
    enable = true;

    # For interactive shells only
    initContent = ''
      
      export SCRIPTS_DIR="$HOME/.scripts"
      export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$BUN_INSTALL/bin:$PATH"
      fpath+=($HOME/.zsh/pure)
      setopt autocd
      zstyle ':completion::complete:cd:*' accept-exact '(*/|)..'
      zstyle ':completion:*' special-dirs true
      autoload -Uz compinit
      compinit

      autoload -U promptinit; promptinit
      prompt pure
      
      zstyle :prompt:pure:git:dirty color '#FAFAB2'
      zstyle :prompt:pure:git:branch color '#66FFA4'
      zstyle :prompt:pure:user color '#99FFCC'
      zstyle :prompt:pure:host color '#99FFFF'
      zstyle :prompt:pure:path color '#E5CCFF'
      zstyle :prompt:pure:prompt:success color '#FFFFFF'
      zstyle :prompt:pure:prompt:error color '#FF0000'
      zstyle :prompt:pure:virtualenv color '#FFFF99'
      zstyle :prompt:pure:continuation color '#FFFF99'

      # Completions
      source <(cobra-cli completion zsh)
      source <(kubectl completion zsh)
      source <(helm completion zsh)
      source <(infractl completion zsh)
    
      # Source custom functions
      source "$HOME/.scripts/helper_funcs/nslookup_k8s.sh"
      source "$HOME/.scripts/helper_funcs/minio_keys.sh"
      source "$HOME/.scripts/helper_funcs/git_helpers.sh"
      source "$HOME/.scripts/helper_funcs/nodepods.sh"
      source "$HOME/.scripts/helper_funcs/podterm.sh"
      source "$HOME/.scripts/helper_funcs/kube_cleanup_terminating.sh"
      source "$HOME/.scripts/helper_funcs/update_bind.sh"
      source "$HOME/.scripts/ssh_utils.sh"
      source "$HOME/.scripts/install_latest_nixhm.sh"
      
      # run ssh-agent in background
      eval "$(ssh-agent -s)"
      bindkey -e

    '';

    shellAliases = {
      p1 = "ping -c 5 1.1.1.1";
      pgg = "ping -c 5 google.com";
      pgw = "ping -c 5 10.0.0.254";
      k = "kubectl";
      cls = "clear";
      ip = "ip --color=auto";
      grep = "grep --color=auto";
      ls = "ls --color=auto";
      ll = "ls -lah --color=auto";
      cat = "bat";
      nsr = "home-manager switch --flake ~/.config/home-manager/#jtrahan -b backup";
      install-nhmg = "pull_build_nixhm";
      create-scripts-tar = "cd $HOME && tar -hczvf _scripts_dir.tar.gz .scripts/";
    };
};

services.ssh-agent.enable = true;
programs.zsh.syntaxHighlighting.enable = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
