#!/usr/bin/env sh
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
