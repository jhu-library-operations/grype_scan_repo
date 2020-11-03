#!/bin/sh

# just in case, set $HOME to / in the container.
export HOME=/

# A way to see if we are running from GitHub actions...
if [ ! -z ${GITHUB_WORKSPACE+x} ]
then

  # GITHUB_WORKSPACE is set, let's check for  a token
  if [ -z ${GITHUB_TOKEN+x} ]
  then
    # No token, error out.
    echo "Error: Unable to get GITHUB_TOKEN" >&2
    echo "Error: Please make sure you set a GITHUB_TOKEN" >&2
    exit 1
  fi
fi

# if GITHUB_WORKSPACE is set, use it.  Otherwise default to /tmp/code
GITHUB_WORKSPACE=${GITHUB_WORKSPACE:-/tmp/code}

# we have a workspace so let's try to run the code.
# $@ should contain our args to the scanner
/bin/grype_scan_repo.sh $@

exit $?