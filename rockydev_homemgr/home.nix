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
    pkgs.docker_28
    pkgs.kubectl
    pkgs.bat
    pkgs.neovim
    pkgs.btop
    pkgs.htop
    pkgs.go
    pkgs.talosctl
    pkgs.shellcheck
    pkgs.rustup
    pkgs.jq
    pkgs.sqlite
    pkgs.postgresql_18
    pkgs.uv
    pkgs.dotnet-sdk
    pkgs.opentofu
    pkgs.libgcc
    pkgs.zig 
    pkgs.ansible 
    pkgs.gnumake
    pkgs.cobra-cli
    pkgs.fastfetch
    pkgs.bat
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

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    ### ssh helper functions ###
    ".scripts/ssh_utils.sh".text = ''
      # Function to start an interactive shell in the specified pod
      purgessh() {
        local hostname=$1
        if [[ -z "$hostname" ]]; then
          echo "Please specify ssh hostname. eg: jtrahan@10.0.0.32"
          return 1
        fi
        ssh-keygen -R $hostname
      }

      # Auto-completion for pod names
      _purgessh_completion() {
          local pods=($(awk '{print $1}' ~/.ssh/known_hosts 2>/dev/null))
          _describe 'hosts' hosts
      }

      # Register the auto-completion for the purgessh function
      compdef _purgessh_completion purgessh

      alias purge-ssh-host=purgessh

      # Function to start an interactive shell in the specified pod
      getknownhost() {
        local hostname=$1
        if [[ -z "$hostname" ]]; then
          echo "Please specify ssh hostname. eg: jtrahan@10.0.0.32"
          return 1
        fi
        sed -n "/$hostname/p" ~/.ssh/known_hosts
      }

      # Auto-completion for pod names
      _getknownhost_completion() {
        local pods=($(awk '{print $1}' ~/.ssh/known_hosts 2>/dev/null))
        _describe 'hosts' hosts
      }

      # Register the auto-completion for the purgessh function
      compdef _getknownhost_completion getknownhost

      alias get-knownhost=getknownhost
    '';

    ### nix home-manager helper funcs - install config from local git repo ###
    ".scripts/install_latest_nixhm.sh".text = ''
      #!/usr/bin/env sh
      pull_build_nixhm () {
        NIXSRCDIR="$HOME/projects/nix-flakes/rockydev_homemgr"
        HMDIR="$HOME/.config/home-manager"
        NIXHOMECFG="$NIXSRCDIR/home.nix"
        export FLAKEKEY="$HMDIR/#jtrahan"
        printf "copying %s to %s...\n" "$NIXHOMECFG" "$HMDIR"
        cp $NIXHOMECFG $HMDIR/home.nix
        printf "copying flake files to %s...\n" "$HMDIR"
        cp $NIXSRCDIR/flake.* $HMDIR/
        printf "rebuild nix hm config: %s...\n" "$FLAKEKEY"
        home-manager switch --flake $FLAKEKEY -b backup
      }
    '';

    # Function to start an interactive shell in the specified pod
    ".scripts/helper_funcs/podterm.sh".text = ''
    podterm() {
      local pod_name=$1
      if [[ -z "$pod_name" ]]; then
        echo "Please specify the pod name."
        return 1
      fi
      kubectl exec --stdin --tty "$pod_name" -- /bin/sh
    }

    # Auto-completion for pod names
    _podterm_completion() {
      local pods=($(kubectl get pods --no-headers -o custom-columns=:metadata.name 2>/dev/null))
      _describe 'pods' pods
    }

    # Register the auto-completion for the podterm function
    compdef _podterm_completion podterm
    '';

    # Function to list pods on a specific node
    ".scripts/helper_funcs/nodepods.sh".text = ''
      nodepods() {
          local node_name=$1
          if [[ -z "$node_name" ]]; then
            echo "Please specify the node name."
            return 1
          fi
          kubectl get pods --field-selector spec.nodeName="$node_name" --all-namespaces -o wide
      }

      # Auto-completion for node names
      _nodepods_completion() {
        local nodes=($(kubectl get nodes --no-headers -o custom-columns=:metadata.name 2>/dev/null))
        _describe 'nodes' nodes
      }

      # Register the auto-completion for the nodepods function
      compdef _nodepods_completion nodepods
    '';

    ### Function to clean up or list terminating pods ###
    ".scripts/helper_funcs/kube_cleanup_terminating.sh".text = ''
      kube_cleanup_terminating_pods() {
          usage() {
              cat <<EOF
      Usage: kube_cleanup_terminating_pods [OPTIONS]

      Find and delete pods stuck in "Terminating" state.

      Options:
        -n, --namespace NS     Specify the namespace to search in
            --all-namespaces   Search across all namespaces
            --show-only        Only list terminating pods (do not delete)
        -h, --help             Show this help message
      EOF
          }

          namespace=""
          all_namespaces=""
          show_only=""

          while [ $# -gt 0 ]; do
              case "$1" in
                  -n|--namespace)
                      shift
                      [ -z "$1" ] && { echo "Error: missing namespace name" >&2; usage; return 1; }
                      namespace="--namespace=$1"
                      ;;
                  --all-namespaces)
                      all_namespaces="--all-namespaces"
                      ;;
                  --show-only)
                      show_only=1
                      ;;
                  -h|--help)
                      usage
                      return 0
                      ;;
                  -*)
                      echo "Unknown option: $1" >&2
                      usage
                      return 1
                      ;;
                  *)
                      break
                      ;;
              esac
              shift
          done

          if [ -n "$namespace" ] && [ -n "$all_namespaces" ]; then
              echo "Error: Cannot use both --namespace and --all-namespaces" >&2
              usage
              return 1
          fi

          if [ -n "$all_namespaces" ]; then
              pods=$(kubectl get pods --all-namespaces | grep Terminating | awk '{print $2 "|" $1}')
              if [ -z "$pods" ]; then
                  echo "No terminating pods found"
                  return 0
              fi
              echo "$pods" | while IFS="|" read -r pod ns; do
                  if [ -n "$show_only" ]; then
                      echo "Terminating pod: $pod (namespace: $ns)"
                  else
                      echo "Deleting pod: $pod (namespace: $ns)"
                      kubectl delete pod "$pod" --namespace="$ns" --grace-period=0 --force
                  fi
              done
          else
              pods=$(kubectl get pods $namespace | grep Terminating | awk '{print $1}')
              if [ -z "$pods" ]; then
                  echo "No terminating pods found"
                  return 0
              fi
              for p in $pods; do
                  if [ -n "$show_only" ]; then
                      echo "Terminating pod: $p $namespace"
                  else
                      echo "Deleting pod: $p $namespace"
                      kubectl delete pod "$p" $namespace --grace-period=0 --force
                  fi
              done
          fi
      }

      # zsh completion for kube_cleanup_terminating_pods
      _kube_cleanup_terminating_pods() {
        local -a opts
        opts=(
          '-n[Specify namespace]:namespace:_kube_namespaces'
          '--namespace[Specify namespace]:namespace:_kube_namespaces'
          '--all-namespaces[Search across all namespaces]'
          '--show-only[Only show terminating pods]'
          '-h[Show help]'
          '--help[Show help]'
        )

        _arguments -s $opts
      }

    # Helper function to fetch namespaces dynamically
    _kube_namespaces() {
      local -a namespaces
      namespaces=($(kubectl get ns --no-headers -o custom-columns=:metadata.name 2>/dev/null))
      _values 'namespaces' $namespaces
    }

    # Register the completion
    compdef _kube_cleanup_terminating_pods kube_cleanup_terminating_pods
    '';
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
      source "$HOME/.scripts/helper_funcs/nodepods.sh"
      source "$HOME/.scripts/helper_funcs/podterm.sh"
      source "$HOME/.scripts/helper_funcs/kube_cleanup_terminating.sh"
      source "$HOME/.scripts/ssh_utils.sh"
      source "$HOME/.scripts/install_latest_nixhm.sh"
      
      # run ssh-agent in background
      eval "$(ssh-agent -s)"

    '';

    shellAliases = {
      k = "kubectl";
      ip = "ip --color=auto";
      grep = "grep --color=auto";
      ls = "ls --color=auto";
      ll = "ls -lah --color=auto";
      cat = "bat";
      nsr = "home-manager switch --flake ~/.config/home-manager/#jtrahan -b backup";
      install-nhmg = "pull_build_nixhm";
    };
};

services.ssh-agent.enable = true;
programs.zsh.syntaxHighlighting.enable = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
