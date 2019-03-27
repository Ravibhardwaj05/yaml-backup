#!/bin/bash

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -o|--outdir)
    OUTDIR="$2"
    shift # past argument
    shift # past value
    ;;
    -k|--kubeconfig)
    KUBECONFIG="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [[ -z $OUTDIR ]] || [[ -z $KUBECONFIG ]]
then
	echo "Missing argument"
	echo "Example: ./backup.sh --OUTDIR /var/lib/backup/rancher --kubeconfig ./kube_config_cluster.yml"
	exit 1
fi

echo "Starting backup..."
DATE="$(date '+%Y%m%d%H%M%S')"
echo "Date: $DATE"

if [[ ! -d $OUTDIR ]]
then
	echo "Missing Backup dir."
	exit 1
fi

cd $OUTDIR
mkdir -p $DATE
if [[ ! -d $DATE ]]
then
	echo "Error: Backup directory wasn't created"
	exit 2
fi
cd $DATE

i=$((0))
for n in $(kubectl --kubeconfig "$KUBECONFIG" get -o=custom-columns=NAMESPACE:.metadata.namespace,KIND:.kind,NAME:.metadata.name pv,pvc,configmap,ingress,service,secret,deployment,statefulset,hpa,job,cronjob --all-namespaces | grep -v 'secrets/default-token')
do
	if (( $i < 1 )); then
		namespace=$n
		i=$(($i+1))
		if [[ "$namespace" == "PersistentVolume" ]]; then
			kind=$n
			i=$(($i+1))
		fi
	elif (( $i < 2 )); then
		kind=$n
		i=$(($i+1))
	elif (( $i < 3 )); then
		name=$n
		i=$((0))
		echo "saving ${namespace} ${kind} ${name}"
		if [[ "$namespace" != "NAMESPACE" ]]; then
			mkdir -p $namespace
			kubectl --kubeconfig "$KUBECONFIG" get $kind -o=yaml --export $name -n $namespace > $namespace/$kind.$name.yaml
		fi
	fi
done

