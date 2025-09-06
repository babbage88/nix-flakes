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
    pkgs.talosctl
    pkgs.kubernetes-helm
    pkgs.bat
    pkgs.neovim
    pkgs.btop
    pkgs.htop
    pkgs.go
    pkgs.shellcheck
    pkgs.rustup
    pkgs.jq
    pkgs.yq-go
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
    pkgs.bind
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
    ".scripts/helper_funcs/minio_keys.sh".text = ''
    create-miniokey() {
      MUSER=''${1-"devuser"}
      mc admin user svcacct add m1 $MUSER
    }
    '';
    ### nslookup_k8s - helper function to performing nslookup for kubernetes service ###
    ".scripts/helper_funcs/nslookup_k8s.sh".text = ''
    nslookup_k8s() {
      usage() {
        /usr/bin/cat <<EOF
    Usage: nslookup_k8s [OPTIONS]

    Run an nslookup inside a Kubernetes pod to test DNS/service resolution.
    If an existing pod/container is not specified, one will be created with 
    the name debug-nslookup

    Options:
      -p, --pod POD           Pod name to exec into (default: debug-nslookup)
      -c, --container NAME    Container name within the pod (default: debug-nslookup)
      -t, --target HOSTNAME   Hostname or pod/service name to resolve (required)
      -n, --namespace NS      Kubernetes namespace (default: current kubectl context namespace)
      -h, --help              Show this help message and exit

    Examples:
      # Use defaults (pod/container "debug-nslookup") in current namespace
      nslookup_k8s --target my-service.default.svc.cluster.local

      # Pick a pod/container and namespace explicitly
      nslookup_k8s --pod mypod --container app --target kubernetes --namespace kube-system
    EOF
      }

      pod="debug-nslookup"
      container="debug-nslookup"
      target=""
      namespace=""

      # short + long option parsing
      while [ $# -gt 0 ]; do
        case "$1" in
          -p|--pod)        pod=$2; shift 2 ;;
          -c|--container)  container=$2; shift 2 ;;
          -t|--target)     target=$2; shift 2 ;;
          -n|--namespace)  namespace="--namespace=$2"; shift 2 ;;
          -h|--help)       usage; return 0 ;;
          --)              shift; break ;;
          -*)
            echo "Unknown option: $1" >&2
            usage
            return 1
            ;;
          *) break ;;
        esac
      done

      if [ -z "$target" ]; then
        echo "Error: --target is required." >&2
        usage
        return 1
      fi

      # Check if pod exists
      if ! kubectl get pod "$pod" $namespace &>/dev/null; then
        echo "Pod $pod not found, creating..."
        kubectl run "$pod" $namespace --image=debian:trixie-slim --restart=Never -- sleep infinity

        echo "Waiting for pod $pod to be ready..."
        kubectl wait $namespace --for=condition=Ready pod/"$pod" --timeout=60s
        if [ $? -ne 0 ]; then
          echo "Pod $pod did not become ready in time." >&2
          return 1
        fi
      fi

      # Run nslookup inside the pod
      kubectl exec -it "$pod" $namespace --container "$container" -- \
        /bin/bash -c "apt-get update -qq && apt-get install -y -qq dnsutils && nslookup $target"
    }

    # ---------------------- zsh completion for nslookup_k8s -----------------------
    # Helper: discover namespace already typed on the command line
    _nslookup_k8s_cli_namespace() {
      local i
      for (( i=1; i<=$#words; i++ )); do
        case ''${words[i]} in
          -n|--namespace)
            echo ''${words[i+1]}
            return
            ;;
          --namespace=*)
            echo ''${words[i]#--namespace=}
            return
            ;;
        esac
      done
    }

    # Helper: discover exec pod already typed (defaults to debug-nslookup if not set)
    _nslookup_k8s_cli_pod() {
      local i
      for (( i=1; i<=$#words; i++ )); do
        case ''${words[i]} in
          -p|--pod)
            echo ''${words[i+1]}
            return
            ;;
          --pod=*)
            echo ''${words[i]#--pod=}
            return
            ;;
        esac
      done
      echo "debug-nslookup"
    }

    # Complete namespaces via kubectl
    _k8s_namespaces() {
      local -a ns
      ns=($(kubectl get ns --no-headers -o custom-columns=:metadata.name 2>/dev/null))
      _values 'namespaces' $ns
    }

    # Complete pods for a given namespace (or current if none)
    _k8s_pods_for_ns() {
      local nsflag=()
      [[ -n "$1" ]] && nsflag=(--namespace "$1")
      local -a pods
      pods=($(kubectl get pods "''${nsflag[@]}" --no-headers -o custom-columns=:metadata.name 2>/dev/null))
      _values 'pods' $pods
    }

    # target completion = pods in namespace, excluding the exec pod
    _nslookup_k8s_complete_target() {
      local ns="$(_nslookup_k8s_cli_namespace)"
      local execpod="$(_nslookup_k8s_cli_pod)"
      local nsflag=()
      [[ -n "$ns" ]] && nsflag=(--namespace "$ns")
      local -a pods filtered
      pods=($(kubectl get pods "''${nsflag[@]}" --no-headers -o custom-columns=:metadata.name 2>/dev/null))
      filtered=()
      for p in $pods; do
        [[ "$p" == "$execpod" ]] && continue
        filtered+="$p"
      done
      compadd -a filtered
    }

    # Main completion dispatcher
    _nslookup_k8s() {
      local curcontext="$curcontext" state
      typeset -A opt_args

      _arguments -s -S \
        '(-h --help)'{-h,--help}'[Show help]' \
        '(-p --pod)'{-p,--pod}'[Pod to exec into (default: debug-nslookup)]:pod name:->pod' \
        '(-c --container)'{-c,--container}'[Container within the pod (default: debug-nslookup)]:container name:' \
        '(-t --target)'{-t,--target}'[Pod/hostname to resolve]:target:->target' \
        '(-n --namespace)'{-n,--namespace}'[Kubernetes namespace]:namespace:_k8s_namespaces' \
        '*::arg:->rest' && return

      case $state in
        pod)
          _k8s_pods_for_ns "$(_nslookup_k8s_cli_namespace)"
          ;;
        target)
          _nslookup_k8s_complete_target
          ;;
      esac
    }

    # Register completion for the function
    autoload -U +X compinit 2>/dev/null && compinit
    compdef _nslookup_k8s nslookup_k8s
    '';

    ### git related helper funcs ###
    ".scripts/helper_funcs/git_helpers.sh".text = ''
    set-gitssh-origin() {
      local baseurl="git@github.com:babbage88"
      local reponame="infra-cli.git"
      local remotename="origin"
      while [[ $# -gt 0 ]]; do
          case "$1" in
              --baseurl)
                  baseurl="$2"
                  shift 2
                  ;;
              --reponame)
                  reponame="$2"
                  shift 2
                  ;;
              --remotename)
                  remotename="$2"
                  shift 2
                  ;;
              -h|--help)
                  echo "Usage: set-gitssh-origin [--baseurl <url>] [--reponame <string>] [--remotename <string>]"
                  echo "  --baseurl   Base Github URL (default: $baseurl)"
                  echo "  --reponame   Repo short name (default: $reponame)"
                  echo "  --remotename The name for the remote entry. (default: $remotename)"
                  echo "  -h, --help    Show this help message"
                  return 0
                  ;;
              *)
                  echo "Unknown argument: $1"
                  echo "Use -h or --help for usage information."
                  return 1
                  ;;
          esac
      done
      echo "Changing $remotename to: $${baseurl}/$${reponame}"
      git remote set-url $remotename $${baseurl}/$${reponame}
      echo
      export outp=$(git remote -v)
      echo "git remote -v commd output:"
      echo $outp
    }
    '';

    ### update-bind command for syncing dns via ansible playbook ###
    ".scripts/helper_funcs/update_bind.sh".text = ''
    update-bind() {
      local inventory="$HOME/projects/Homelab.Configs/ansible/playbooks/dns/inventory"
      local playbook="$HOME/projects/Homelab.Configs/ansible/playbooks/dns/main.yml"

      while [[ $# -gt 0 ]]; do
          case "$1" in
              --inventory)
                  inventory="$2"
                  shift 2
                  ;;
              --playbook)
                  playbook="$2"
                  shift 2
                  ;;
              -h|--help)
                  echo "Usage: run_ansible [--inventory <path>] [--playbook <path>]"
                  echo "  --inventory   Path to Ansible inventory file (default: $inventory)"
                  echo "  --playbook    Path to Ansible playbook file (default: $playbook)"
                  echo "  -h, --help    Show this help message"
                  return 0
                  ;;
              *)
                  echo "Unknown argument: $1"
                  echo "Use -h or --help for usage information."
                  return 1
                  ;;
          esac
      done

      ansible-playbook -i "$inventory" "$playbook"
    }

    flush-dns(){
      sudo systemctl restart systemd-resolved.service
    }

    '';

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
            /usr/bin/cat <<EOF
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

    delete_zero() {
        local namespace="default"
        while [[ $# -gt 0 ]]; do
            case "$1" in
            -n | --namespace)
                namespace="$2"
                shift 2
                ;;
            -h | --help)
                echo "Usage: delete_zero [--namespace <namespace>]"
                echo "  -n, --namespace   Base Github URL (default: $namespace)"
                echo "  -h, --help    Show this help message"
                return 0
                ;;
            *)
                echo "Unknown argument: $1"
                echo "Use -h or --help for usage information."
                return 1
                ;;
            esac
        done
        export namespace
        echo "Deleteing replicasets with 0 replicas in namespace: $namespace"
        kubectl -n $namespace get replicaset -o json |
            jq -r '.items[] | select(.spec.replicas == 0) | .metadata.name' |
            xargs kubectl -n $namespace delete replicaset
    }
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
