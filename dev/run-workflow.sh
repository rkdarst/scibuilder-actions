#/bin/bash


usage() {
  cat << EOF
Run a workflow using act.

Usage:
  $0 WORKFLOW_FILE [BRANCH]

This script should be called from the main folder of the repository.

Workflow file should be a GitHub workflow.

If branch is not specified, the script will use the current branch of the repository.
EOF
}

RUNTIME="podman"
ROOTLESS=0

for ARG in "$@"
  do
  case $ARG in
    -h|--help)
    shift
    usage
    exit 0
    ;;
    -d|--docker)
    RUNTIME=docker
    shift
    ;;
    -r|--no-rootless)
    ROOTLESS=1
    shift
    ;;
  esac
done

if [[ "$ROOTLESS" -eq 0 ]] && [[ "$RUNTIME" == "podman" ]]
then
  PODMAN_SOCKET=$XDG_RUNTIME_DIR/podman/podman.sock
  export DOCKER_HOST=unix://$PODMAN_SOCKET
  ACT_CONTAINER_SOCKET="--container-daemon-socket $PODMAN_SOCKET"
fi

if [[ "$#" -lt 1 ]] ; then
  echo "Error: No workflow file given!"
  echo
  usage
  exit 1
fi

WORKFLOW="$1"

if [ ! -f "$WORKFLOW" ]; then
  echo "Error: Workflow file \"$WORKFLOW\" does not exist!"
  echo
  usage
  exit 1
fi

if [[ "$#" -lt 2 ]] ; then
  BRANCH=$(git branch --show-current 2> /dev/null)
  RESULT=$?
  if [[ "$RESULT" -ne 0 ]] ; then
    echo "Error: Missing a branch and could not get the current branch!"
    echo
    usage
    exit 1
  fi
else
  BRANCH=$2
fi

EVENTFILE=$(mktemp --suffix -push-$BRANCH.json)

cat > $EVENTFILE << EOF
{
  "ref": "refs/heads/$BRANCH",
  "ref_name": "$BRANCH",
  "ref_type": "branch"
}
EOF

trap "rm $EVENTFILE" EXIT

echo "Running workflow \"$WORKFLOW\" with push from branch $BRANCH"

time act push -b $ACT_CONTAINER_SOCKET -P self-hosted=docker.io/catthehacker/ubuntu:act-22.04 -W $WORKFLOW -e $EVENTFILE
