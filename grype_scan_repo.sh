#!/bin/bash
IFS=$(echo -en "\n\b")
returnCode=0
dockerfile="Dockerfile"
imageline="^FROM"
install=0
dryrun=0
cleanup=0

while [ $# -gt 0 ]
do
	key="$1"
	case "$key" in
		--dry-run) 
			dryrun=1
			shift #past the arg
			;;
		-c)
			dockerfile="docker-compose.yml"
			imageline=".*image:"
			shift # past the arg
			;;
		-i) 
			install=1
			shift
			;;
		-r)
			cleanup=1
			shift # past the arg
			;;
		-h|--help)
			echo -e "\n$0: [-ci] [-h|--help]"
			echo -e "\t-c         Scan for docker-compose.yml files instead of Dockerfiles"
			echo -e "\t--dry-run  Does a dry run, doesn't pull images or scan."
			echo -e "\t-r         Remove images after scan."
			echo -e "\t-i         Install grype into ~/bin/ and exit."
			echo -e "\t-h|--help  Display this help.\n"
			exit 1
			;;
		*)
			echo "Error: Unrecognized option $key" >&2
			exit 1
			;;
	esac
done

if [ $install -eq 1 ]
then
	# do a grype install to ~/bin/
	mkdir -p ~/bin/
	makeDir=`mktemp -d`
	mkdir -p $makeDir
	oldDir=`pwd`
	cd $makeDir
	git clone https://github.com/anchore/grype.git
	if [ $? -ne 0 ]
	then	
		echo "Error: Unable to clone repo." >&2
		cd $oldDir
		rm -rf $makeDir
		exit 1
	fi

	cd grype 
	go build -o grype.bin
	if [ $? -ne 0 ]
	then	
		echo "Error: Unable to build grype." >&2
		cd $oldDir
		rm -rf $makeDir
		exit 1
	fi

	/bin/cp -v grype.bin ~/bin/grype
	if [ $? -ne 0 ]
	then	
		echo "Error: Unable to copy grype to ~/bin/" >&2
		cd $oldDir
		rm -rf $makeDir
		exit 1
	fi
	chmod 700 ~/bin/grype

	cd $oldDir
	rm -rf $makeDir
	echo -e "\nGrype has been successfully installed.\n"
	exit 0
fi

for dFile in `find $PWD -name $dockerfile`
do
	echo "Found: $dFile"

	dFileDir=`dirname $dFile`

	# grab the list of images to grab from this file
	for imgName in `cat $dFile | grep $imageline | sed -e "s/$imageline //g" | sed -e "s/ as .*$//"`
	do
		vulCount="0"
		echo -ne "*** Telling docker to pull the image $imgName ..."
		if [ $dryrun -eq 0 ]
		then
			docker pull $imgName >/dev/null 2>&1
		else
			echo -ne "\n*** DRYRUN: would have pulled $imgName... "
		fi
		echo -e "Done"
		# transform slashes in the image name to underscores for the logfile name
		imgLogName=`echo $imgName | sed -e 's/\//_/g'`
		echo -ne "*** Scanning image with grype... "
		#grype $imgName > ${dFileDir}/${imgLogName}.grypelog.txt 2>&1
		#echo "grype $imgName -o json -q | tee ${dFileDir}/${imgLogName}.grypelog.json  |  jq -r \".matches\" | jq \". | length\""
		if [ $dryrun -eq 0 ]
		then
			vulCount=`grype $imgName -o json -q | tee ${dFileDir}/${imgLogName}.grypelog.json  |  jq -r ".matches" | jq ". | length"`
		else
			vulCount=0
			echo -ne "\n*** DRYRUN: Would have run the following: \n"
			echo -ne "***        grype $imgName -o json -q | tee ${dFileDir}/${imgLogName}.grypelog.json ... "
		fi
		echo -e "Done."
		if [ $cleanup -eq 1 ] && [ $dryrun -eq 0 ]
		then
			echo "*** Cleaning up image."
			docker rmi $imgName
		fi
		if [ "$vulCount" == "" ]
		then
			echo -e "*** Error running grype.\n"
			returnCode=2
			continue
		fi
		if [ $dryrun -eq 0 ]
		then
			echo -e "*** Found $vulCount vulnerabilites. (Log saved to ${dFileDir}/${imgLogName}.grypelog.json)\n"
		else
			echo -e "*** DRYRUN: Scanning skipped.\n"
		fi
		if [ $vulCount -gt 0 ]
		then
			returnCode=1
		fi
	done	
done
if [ "$returnCode" == "1" ]
then
	echo "Error: Vulnerabilities found."
fi
exit $returnCode
