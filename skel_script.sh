#!/bin/bash

MODE="$1"
GIT_URL="$2"
HASH_LIST=$(mktemp)
DIFF_FILE=$(mktemp)
KEY_DIR=$(mktemp -d)
GUSER=""

hash_collector(){
	trufflehog --regex  --entropy=False $(echo $1) | grep "Reason: .* key" -A 2 | grep "Hash:" | awk -F" " '{print $2}' | sort -u | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" 
}


if [[ "$MODE" == "user" ]]; then
	GUSER="$GIT_URL"
	GIT_URL=""
	USER_REPOS=$(mktemp)
	curl -s "https://api.github.com/users/$GUSER/repos" | grep "clone_url" | awk -F\" '{print $4}' > $USER_REPOS
else
	if [[ "$MODE" == "local" ]]; then
		hash_collector "git_url --repo_path $GIT_URL" >  $HASH_LIST	
	elif [[ "$MODE" == "remote" ]]; then
		hash_collector "$GIT_URL" >  $HASH_LIST	
	fi

	if [[ "$(wc -l $HASH_LIST | awk -F" " '{print $1}')" -ne "0" ]]; then
		if [[ "$MODE" == "remote" ]]; then
			GIT_DIR=$(mktemp -d)
			git clone $GIT_URL $GIT_DIR
			cd $GIT_DIR
		else
			cd $GIT_URL
		fi
		
		cat $HASH_LIST | while IFS= read -r line; do 		
			DIFF_FILE=$(mktemp)
			KEY_FILE=${KEY_DIR}/private_key_$(echo $GIT_URL | awk -F/ '{print $NF}' | awk -F. '{print $1}')_${line}
			git show $line | sed -r "s/^([^-+ ]*)[-+ ]/\\1/" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" > $DIFF_FILE; 
			awk '/^-----BEGIN [A-Z]* PRIVATE (KEY|KEY BLOCK)-----$/{flag=1}/^-----END [A-Z]* PRIVATE (KEY|KEY BLOCK)-----$/{print;flag=0}flag' $DIFF_FILE > $KEY_FILE
			if [[ "$(wc -l $KEY_FILE | awk -F" " '{print $1}')" == "0" ]]; then
				rm -f $KEY_FILE
			fi
			rm -f $DIFF_FILE
		done
		cd /tmp/
		if [[ "$MODE" == "remote" ]]; then
			rm -rf $GIT_DIR
		fi
		
		if [[ "$(ls -1 $KEY_DIR | wc -l)" == "0" ]]; then
			rmdir $KEY_DIR
			echo "No keys found."
		else
			echo "Collected keys at: $KEY_DIR"
		fi
	fi
fi


