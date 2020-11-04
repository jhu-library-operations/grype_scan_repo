#!/bin/sh
IFS=$(echo -en "\n\b")
returnCode=0
dockerfile='.*\/Dockerfile'
imageline="^FROM"
install=0
dryrun=0
cleanup=0
output=0 
sevfilter="(Critical|High|Medium|Low|Unknown)"
totalvulcount=0
warning=0 
grype_tag=v0.2.0

while [ $# -gt 0 ]
do
	key="$1"
	case "$key" in
		--dry-run) 
			dryrun=1
			shift #past the arg
			;;
		-c)
			dockerfile='.*\/docker-compose.yml'
			imageline=".*image:"
			shift # past the arg
			;;
		-k)
			dockerfile='.*.\(yml\|yaml\)'
			imageline=".*image:"
			shift #past the arg
			;;
		-i) 
			install=1
			shift
			;;
		-r)
			cleanup=1
			shift # past the arg
			;;
		-o)
			output=1
			shift # past the arg
			;;
		-s) 
			sevfilter=$2
			shift # the arg
			shift # the value
			;;
		-h|--help)
			echo -e "\n$0: [-ci] [-h|--help]"
			echo -e "\t-c          Scan for docker-compose.yml files instead of Dockerfiles"
			echo -e "\t-k          Scan for *.yml and *.yaml files (kubernetes) "
			echo -e "\t--dry-run   Does a dry run, doesn't pull images or scan."
			echo -e "\t-o          Show output instead of logging it."
			echo -e "\t-i          Install grype and crane into ~/bin/ and exit."
			echo -e "\t-s <filter> The severities to filter for, an egrep pattern. "
			echo -e "\t              (default: '(Critical|High|Medium|Low|Unknown)'"
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
	
	git fetch --all --tags #> /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		echo "Error: Unable to fetch grype tags"
		cd $oldDir
		rm -rf $makeDir
		exit 1
	fi

	git checkout tags/$grype_tag -b build
	if [ $? -ne 0 ]
	then
		echo "Error: Unable to checkout grype branch: $grype_tag"
		cd $oldDir
		rm -rf $makeDir
		exit 1
	fi
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

	echo -e "Installing crane for image pulls\n"
	GO111MODULE=on go get -u github.com/google/go-containerregistry/cmd/crane
	if [ $? -ne 0 ]
	then	
		echo "Error: Unable to build crane"
		exit 1
	fi

	/bin/mv -v ~/go/bin/crane ~/bin
	chmod 755 ~/bin/crane 
	go clean -cache -modcache
	
	exit 0
fi

# let's create a temp file to hold the found images.
makeDir=`mktemp -d`
mkdir -p $makeDir
imgList="$makeDir/imgList.txt"
touch $imgList

if [ $dryrun -eq 1 ]
then	
	echo "Image List: $imgList"
fi


for dFile in `find $PWD -type f -regex $dockerfile`
do
	if [ $dryrun -eq 1 ]
	then
		echo "Found: $dFile"
	fi

	dFileDir=`dirname $dFile`

	# grab the list of images to grab from this file
	for imgName in `cat $dFile | grep $imageline | sed -e "s/$imageline //g" | sed -e "s/ as .*$//"`
	do
		# add the image name to the list
		echo $imgName >> $imgList
	done
done

# now let's try to clean up the file
cat $imgList | sort -u > ${imgList}.sorted

# now let's try to process just the images we found
for imgName in `cat ${imgList}.sorted`
do
	# transform slashes in the image name to underscores for the logfile name
	imgLogName=`echo $imgName | sed -e 's/\//_/g' | sed -e 's/\:/_/g'`
	
	vulCount="0"
	echo -ne "*** Trying to pull the image $imgName ... \n"
	if [ $dryrun -eq 0 ]
	then
	
		crane pull $imgName $makeDir/${imgLogName}.tar > /dev/null 2>&1 

		if [ $? -ne 0 ]
		then	
			echo "Error: Unable to pull $imgName" >&2
			# this is a non fatal error so set the warning flag and keep going.
			warning=1
		fi
	else
		echo -ne "\n*** DRYRUN: would have ran the following to pull: \n"
		echo -ne "\t*** 			crane pull $imgName $makeDir/${imgLogName}.tar"
	fi
	echo -e "*** Done"
	echo -ne "*** Scanning image with grype ... "
	if [ $dryrun -eq 0 ]
	then
		if [ $output -eq 0 ]
		then
			vulCount=`grype $makeDir/${imgLogName}.tar -q | egrep $sevfilter | tee ${imgLogName}.grypelog |  wc -l `
		else
			echo
			grype $makeDir/${imgLogName}.tar -q | egrep $sevfilter | tee ${imgLogName}.grypelog | while read line; do echo -e "*** $line"; done
			vulCount=`cat ${imgLogName}.grypelog | wc -l`
			echo -en "*** "
		fi
		totalvulcount=$((totalvulcount + vulCount))
	else
		vulCount=0
		echo -ne "\n*** DRYRUN: Would have run the following: \n"
		echo -ne "***        grype $makeDir/${imgLogName}.tar -q | tee ${imgLogName}.grypelog ... "
	fi
	echo -e "Done."
	if [ "$vulCount" == "" ]
	then
		echo -e "*** Error running grype.\n"
		returnCode=2
		continue
	fi
	
	echo -e "*** Cleaning up image"
	rm -f $makeDir/${imgLogName}.tar
	
	if [ $dryrun -eq 0 ]
	then
		if [ $vulCount -eq 0 ]
		then
			echo -e "*** No vulnerabilities found. \n"
			rm -f ${imgLogName}.grypelog
		else
			echo -e "*** Found $vulCount vulnerabilites. (Log saved to ${imgLogName}.grypelog)\n"
		fi
	else
		echo -e "*** DRYRUN: Scanning skipped.\n"
	fi
	if [ $vulCount -gt 0 ]
	then
		returnCode=1
	fi

done	
if [ "$returnCode" == "1" ]
then
	echo "Error: $totalvulcount Vulnerabilities found."
fi

# if there were non-fatal warnings/errors, return zero so 
# the user knows something went wrong.
if [ $warning -eq 1 ]
then
	returnCode=1
fi

# clean up ourselves
rm -rf $makeDir
exit $returnCode
