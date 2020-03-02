#!/bin/bash

## Variable initialization
MODE="local"
PAYLOAD=$(pwd)
HASH_LIST=$(mktemp)
KEY_DIR=$(mktemp -d)
USER_REPLY=""

## Set bash strict mode
set -e # Stop the execution if any program used exits with a non-zero code
set -u # Stop the execution if any reference to an unboun variable is made
set -o pipefail # Disable pipeline failure masking


## Define functions

## Define help function
Usage(){
	echo -e "\nUsage:"
	echo    " 		-m PROCESSING_MODE 	Sets the operating scope to: local, remote or github_user. The default mode is local."
	echo 	" 		-p PAYLOAD 		Depending on the PROCESSING_MODE, sets the local repo path, the remote repo url or the github_user's name."
	echo  	" 		-h 			Display usage guide."
	echo -e "\nDefaults:"
	echo 	" 		MODE 	-> \"local\" "
	echo    " 		PAYLOAD -> \$PWD: \"$(pwd)\" "
}


# Collect hashes with private keys from a repo. truffleHog exits with 1 if it detects anything, so we have to turn off the error instant exit for this operation
hash_collector(){
	set +e
	trufflehog --regex  --entropy=False $(echo $1) | grep "Reason: .* key" -A 2 | grep "Hash:" | awk -F" " '{print $2}' | sort -u | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" 
	set -e
}

# Loop through the collected hashes, git show each of them, strip the =/- signs and the color metadata and pass them through the private key regex. If repo is remote, it's cloned, processed and then deleted. Any key detected by the regex gets saved as $KEY_DIR/$REPO_NAME/findings_from_hash_$COMMIT_HASH
process_repo(){
if [[ "$(wc -l $2 | awk -F" " '{print $1}')" -ne "0" ]]; then	
	echo -e "High signal entropy detected by regexes for repo \"$1\".\n"
	if [[ "$3" == "remote" ]]; then
		GIT_DIR=$(mktemp -d)
		git clone $1 $GIT_DIR > /dev/null 2>&1
		cd $GIT_DIR
	else
		cd $1
	fi
	REPO_KEYS=${KEY_DIR}/$(basename $(git remote get-url origin) | awk -F. '{print $1}')	
	mkdir $REPO_KEYS
	cat $2 | while IFS= read -r commit_hash; do 		
		DIFF_FILE=$(mktemp)
		KEY_FILE=${REPO_KEYS}/findings_from_hash_${commit_hash}
		git show $commit_hash | sed -r "s/^([^-+ ]*)[-+ ]/\\1/" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" > $DIFF_FILE; 
		awk '/^-----BEGIN [A-Z]* PRIVATE (KEY|KEY BLOCK)-----$/{flag=1}/^-----END [A-Z]* PRIVATE (KEY|KEY BLOCK)-----$/{print;flag=0}flag' $DIFF_FILE > $KEY_FILE
		if [[ "$(wc -l $KEY_FILE | awk -F" " '{print $1}')" == "0" ]]; then
			rm -f $KEY_FILE > /dev/null 2>&1
		fi
		rm -f $DIFF_FILE > /dev/null 2>&1
	done
	cd /tmp/
	if [[ "$3" == "remote" ]]; then
		rm -rf $GIT_DIR > /dev/null 2>&1
	fi

	if [[ "$(ls -1 $REPO_KEYS | wc -l)" == "0" ]]; then	
		rmdir $REPO_KEYS > /dev/null 2>&1
		echo "No keys found for repo \"$1\"."
	else
		echo "Collected keys for repo \"$1\" at:\"$REPO_KEYS\""
	fi
else 
	echo "No private keys detected through high signal regexes for repo \"$1\"."
fi
}

# Transverse through the $KEY_DIR and print all relevant findings
key_transverser(){
	cd $1
	for file in $1/*;do 	
		if [ -d "$file" ]; then 
			key_transverser "$file"
			cd ..
		else
			echo -e "\n$file\n"
			cat $file
		fi
    	done
}

set +u # Avoid having double error triggering by unbound variable checks on the argparse block, as the argparser will autotrigger if an arg is not complete

## Arg parsing
while getopts ":m:p:h" opt; do
	case $opt in
		m)
			MODE=$OPTARG # Set processing mode
			;;
		p)
			PAYLOAD=$OPTARG # Set processing payload
			;;
		h)
			Usage
			exit 0
			;;
		\?)
			echo "Invalid option: -$OPTARG"
			Usage
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument."
			Usage
			exit 1
			;;
	esac
done
set -u # Re-enable unbound variable check

# Very basic input sanitization
if [[ "$MODE" != "local" ]] && [[ "$MODE" != "remote" ]] && [[ "$MODE" != "github_user" ]]; then
	echo -e "\nBad arguments!"
	Usage
	exit 1
fi



## Program start

# Main execution. Depending on the mode selected different input sanitizations and checks take place to ensure smooth execution. Curl requests also tend to return weird exit codes so the instant exit on error is disabled for curl segments and for the truffleHog check for remote repos.
if [[ "$MODE" == "github_user" ]]; then
	set +e
	URL_CHECK=$(curl -s --head "https://github.com/${PAYLOAD}/" | head -n 1 | awk -F" " '{print $(NF-1)" "$NF}')
	set -e
	if [[ "${URL_CHECK%?}" != "200 OK" ]] && [[ "${URL_CHECK%?}" != "200 " ]]; then
		echo -e "\n\"https://github.com/${PAYLOAD}\" does not exist or is private."
		exit 1	
	else
		echo -e "\n\"https://github.com/${PAYLOAD}\" exists."
	fi
	
	USER_REPOS=$(mktemp)
	set +e
	curl -s "https://api.github.com/users/${PAYLOAD}/repos" | grep "clone_url" | awk -F\" '{print $4}' > $USER_REPOS
	set -e
	if [[ "$(wc -l $USER_REPOS | awk -F" " '{print $1}')" == "0" ]]; then
		echo -e "\nUser \"$PAYLOAD\" does not have any public repositories or does not exist\n"
		exit 0
	else
		echo -e "\nProcessing the following repositories:\n"
		cat $USER_REPOS
		echo -e "\n"
	fi
	
	cat $USER_REPOS | while IFS= read -r line; do
		GIT_URL=$line
		hash_collector $GIT_URL > $HASH_LIST
		process_repo $GIT_URL $HASH_LIST "remote"
	done

else
 	if [[ "$MODE" == "local" ]]; then
		if [ -d $PAYLOAD ]; then
	    		echo -e "\nDirectory exists."
			if [[ "${PAYLOAD: -1}" == "/" ]]; then
				PAYLOAD=${PAYLOAD%?}
			fi
			if [ -d ${PAYLOAD}/.git ]; then
				echo "Directory is a git repository."
			else
				echo "Directory \"$PAYLOAD\" is not a git repository."
				exit 1
			fi
		else
			echo -e "\nDirectory \"$PAYLOAD\" does not exist."
			exit 1
		fi
		echo -e "\nProcessing local repo \"$PAYLOAD\".\n"
		hash_collector "git_url --repo_path $PAYLOAD" >  $HASH_LIST
	elif [[ "$MODE" == "remote" ]]; then
		if [[ "${PAYLOAD: -4}" == ".git" ]]; then # curl requests on dot git addresses return 301s
			PAYLOAD=${PAYLOAD%????}
		fi
		set +e
		URL_CHECK=$(curl -s --head "$PAYLOAD" | head -n 1 | awk -F" " '{print $(NF-1)" "$NF}')	
		set -e
		if [[ "${URL_CHECK%?}" != "200 OK" ]] && [[ "${URL_CHECK%?}" != "200 " ]]; then
			echo -e "\nThe provided url \"$PAYLOAD\" does not exist or is private."
			exit 1
		else
			echo -e "\nURL is reachable."
		fi
		VALIDITY_CHECK=$(mktemp)
		set +e
		trufflehog $PAYLOAD > $VALIDITY_CHECK 2>&1	
		set -e
		if grep -q "fatal" $VALIDITY_CHECK; then
			echo "Provided url \"$PAYLOAD\" is not a valid git repository."
			exit 1
		else
			rm -rf $VALIDITY_CHECK
		fi
		echo -e "\nProcessing remote repo \"$PAYLOAD\".\n"
		hash_collector $PAYLOAD >  $HASH_LIST	
	fi
	process_repo $PAYLOAD $HASH_LIST $MODE
fi


# Final cleanup and/or key printing
rm -f $HASH_LIST > /dev/null 2>&1

if [[ "$(ls -1 $KEY_DIR | wc -l)" == "0" ]]; then	
	rmdir $KEY_DIR > /dev/null 2>&1
	echo -e "\n"
	exit 0
fi


read -r -p "Print collected keys? [Y/n] " USER_REPLY

case $USER_REPLY in
    		[yY][eE][sS]|[yY])
 		key_transverser $KEY_DIR
		;;
    		[nN][oO]|[nN])
 		true
       		;;
	"")
		key_transverser $KEY_DIR	
		;;
	*)
 		true
 		;;
esac


if [[ "$MODE" == "github_user" ]]; then
	echo -e "\nCollected keys for all repos at:\"$KEY_DIR\""
fi

echo -e "\n"
# Program exit
exit 0


