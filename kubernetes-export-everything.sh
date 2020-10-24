#
# exporting everything from kubernetes, except events
# one argument required : the kubectl context
#
# tools required :
# - GNU parallel, not parallel from moreutils
# - GNU sed, not the default one from MacOS which is the 2005 FreeBSD one
# - GNU bash v5, not the default one from MacOS which is the v3 from 2007
# - kubectl, tested on 1.19
#

if [ "$#" -ne 1 ]
then
  echo "Usage: $0 kubectl_context"
  exit 1
fi

# a context directory will created to store the data
CONTEXT=$1

# cleanup of timestamps and other fields which are changing all the time
# on MacOS, use 'gsed'
SED_CMD="eval sed -e '/^\ \ \ \ control-plane.alpha.kubernetes.io\\\/leader.*/d' -e '/\ resourceVersion:\ /d' -e '/^\ \ lastScheduleTime:\ /d' -e '/^\ \ -\ lastHeartbeatTime:\ /d'"

# objects with a namespace
api_resources=`kubectl --context $CONTEXT api-resources --verbs=list,get --namespaced=true --no-headers | awk '{print $1}' | sort | grep -v '^events$'`
for api_resource in $api_resources;do
  while read -r namespace object other ; do
    [[ -z "$namespace" ]] && break # escape if nothing found
    echo "-> $api_resource : $namespace $object"
    mkdir -p $CONTEXT/$namespace/$api_resource
    echo "kubectl --context $CONTEXT --namespace $namespace get $api_resource $object --output yaml | $SED_CMD > ./$CONTEXT/$namespace/$api_resource/$object.yaml" >> $CONTEXT.commands.sh
    # decoding secrets
    if [[ "$api_resource" == 'secrets' ]]; then
        echo "kubectl --context $CONTEXT --namespace $namespace get $api_resource $object -o go-template='{{range \$k,\$v := .data}}{{printf \"%s: \" \$k}}{{\$v | base64decode}}{{\"\n\"}}{{end}}'  > ./$CONTEXT/$namespace/$api_resource/${object}_decoded.yaml" >> $CONTEXT.commands.sh
    fi
  done <<< $( kubectl --context $CONTEXT get "$api_resource" --no-headers --all-namespaces 2>&1 | grep -v "No resources found\|Error" )
done

# objects without a namespace
api_resources=`kubectl --context $CONTEXT api-resources --verbs=list,get --namespaced=false --no-headers | awk '{print $1}' | sort`
for api_resource in $api_resources;do
  while read -r object other ; do
    [[ -z "$object" ]] && break # escape if nothing found
    echo "-> $api_resource : $object"
    mkdir -p $CONTEXT/no-namespace/$api_resource
    echo "kubectl --context $CONTEXT get $api_resource $object --output yaml | $SED_CMD > ./$CONTEXT/no-namespace/$api_resource/$object.yaml " >> $CONTEXT.commands.sh
  done <<< $( kubectl --context $CONTEXT get "$api_resource" --no-headers 2>&1 | grep -v "No resources found\|Error" )
done

# how many cores?
if [ "$(uname)" == "Darwin" ]; then
  number_of_cores=$(sysctl -n hw.ncpu)
else
  number_of_cores=$(grep -c processor /proc/cpuinfo)
fi

# required : GNU parallel
time parallel --will-cite --progress --eta --jobs $number_of_cores -a $CONTEXT.commands.sh

# deleting the commmands file
rm -f $CONTEXT.commands.sh
