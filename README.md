# kubernetes-export-everything

Just a bash script to export all the resources, as YAML files

Folder structure created will follow this pattern : `context/namespace/resource_type/resource_name.yaml`  
The kubectl context is the only argument to the script.  
The script will download all the objects in parallel, using one thread per CPU core available, in order to optimise the download speed.  
Kubernetes events won't be downloaded, and some parts of the YAML which is changing at each export will also be stripped out. This can be configured on line 23.  
Secrets will also be decoded, with the suffix `_decoded.yaml`  
You can use this script for example as part of a scheduled task which will commit to git the current state of your cluster, to be able to see what is being modified every day.  

## Setup

The tools required are :
 - GNU parallel, not parallel from moreutils
 - GNU sed, not the default one from MacOS which is the 2005 FreeBSD one
 - GNU bash v5, not the default one from MacOS which is the v3 from 2007
 - kubectl, tested on 1.19

### MacOS
```sh
brew install bash gnu-sed parallel
```
Replace 'sed' by 'gsed' on line 23.
Launch the script with `/usr/local/bin/bash`

### Ubuntu
```
sudo apt-get install parallel
```

### Alpine
```
apk add parallel bash
```
Launch the script with `/bin/bash`

