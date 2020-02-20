#!/bin/bash

GIT_URL="https://github.com/user/repo.git"
HASH_LIST=$(mktemp)
DIFF_FILE=$(mktemp)
KEY_DIR=$(mktemp -d)

trufflehog --regex  --entropy=False $GIT_URL | grep "Reason: .* key" -A 2 | grep "Hash:" | awk -F" " '{print $2}' | sort -u > $HASH_LIST

if [[ "$(wc -l $HASH_LIST | awk -F" " '{print $1}')" -ne "0" ]]; then
	GIT_DIR=$(mktemp -d)
	git clone $GIT_URL $GIT_DIR
	cd $GIT_DIR
	cat $HASH_LIST | while IFS= read -r line; do 		
		DIFF_FILE=$(mktemp)
		git show $line | sed -r "s/^([^-+ ]*)[-+ ]/\\1/" > $DIFF_FILE; 
		awk '/^-----BEGIN [A-Z]* PRIVATE (KEY|KEY BLOCK)-----$/{flag=1}/^-----END [A-Z]* PRIVATE (KEY|KEY BLOCK)-----$/{print;flag=0}flag' $DIFF_FILE > ${KEY_DIR}/private_key_$(echo $GIT_URL | awk -F/ '{print $NF}' | awk -F. '{print $1}')_${line}
		rm -f $DIFF_FILE
	done
	cd /tmp/
	rm -rf $GIT_DIR
	echo "Collected keys at: $KEY_DIR"
fi


