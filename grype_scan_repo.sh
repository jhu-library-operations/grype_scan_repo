#!/bin/bash
IFS=$(echo -en "\n\b")
returnCode=0
dockerfile="Dockerfile"
imageline="^FROM"
install=0
	 
while [ $# -gt 0 ]
do
	key="$1"
	case "$key" in
		-c)
			dockerfile="docker-compose.yml"
			imageline=".*image:"
			shift # past the arg
			;;
		-i) 
			install=1
			shift
			;;
		-h|--help)
			echo -e "\n$0: [-ci] [-h|--help]"
			echo -e "\t-c         Scan for docker-compose.yml files instead of Dockerfiles"
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
		docker pull $imgName >/dev/null 2>&1
		echo -e "Done"
		# transform slashes in the image name to underscores for the logfile name
		imgLogName=`echo $imgName | sed -e 's/\//_/g'`
		echo -ne "*** Scanning image with grype... "
		#grype $imgName > ${dFileDir}/${imgLogName}.grypelog.txt 2>&1
		#echo "grype $imgName -o json -q | tee ${dFileDir}/${imgLogName}.grypelog.json  |  jq -r \".matches\" | jq \". | length\""
		vulCount=`grype $imgName -o json -q | tee ${dFileDir}/${imgLogName}.grypelog.json  |  jq -r ".matches" | jq ". | length"`
		
		echo -e "Done."
		if [ "$vulCount" == "" ]
		then
			echo -e "*** Error running grype.\n"
			returnCode=1
			continue
		fi
	       	echo -e "*** Found $vulCount vulnerabilites. (Log saved to ${dFileDir}/${imgLogName}.grypelog.json)\n"

		if [ '$vulCount' > 0 ]
		then
			returnCode=1
		fi
	done	
done
if [ "$returnCode" != "0" ]
then
	echo "Error: Vulnerabilities found."
fi
exit $returnCode
