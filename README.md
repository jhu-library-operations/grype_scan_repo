# grype_scan_repo
A wrapper around the grype command that should allow you to scan Dockerfiles, docker-compose.yml files, or \*.yml|\*.yaml (Kubernetes manifests)  for vulnerabilities in the base images.  [Grype](https://github.com/anchore/grype) is a useful tool to baseline security risks in container setups you are developing.  It doesn't catch everything, like any scanner it's not perfect, but it is a good way to get a good start on the risks currently in your base images.


```
./grype_scan_repo.sh: [-ciko] [--dry-run] [-s <egrep_severity_filter>] [-f <egrep_package_exclude_filter>] [-h|--help]

        -c              Scan for docker-compose.yml files instead of Dockerfiles
        -k              Scan for *.yml and *.yaml files (kubernetes)
        --dry-run       Does a dry run, doesn't pull images or scan.
        -o              Show output instead of logging it.
        -i              Install grype and crane into ~/bin/ and exit.
        -s <severity>   The severities to filter for, an egrep pattern.
                        (default: '(Unknown|Negligible|Low|Medium|High|Critical)')
        -f <pkg-filter> Package names to filter out, this is an egrep pattern to EXCLUDE pattern.
        -h|--help       Display this help.

```

## Installation
I find it easiest to download a copy of the shell script to ~/bin/ and make sure that ~/bin/ is in my $PATH.  If you don't already have grype, you can grab it with the `-i` flag.  This script also uses [crane](https://github.com/google/go-containerregistry/blob/master/cmd/crane/doc/crane.md) to do the image pulls to a .tar file instead of using the `docker` command.  This means you can use this script without needing to install the full docker stack.  The `-i` option will also download and install `crane` to your ~/bin/ directory, automagically.

## Docker usage
You can also use this as a container.  You can use a command like this:

`# docker pull ghcr.io/jhu-library-operations/grype_scan_repo/grype-scan-repo:latest`

Once you have the image locally, you can run it like this:

`docker run -it -v /home/user/projects/repo-to-scan/:/tmp/code ghcr.io/jhu-library-operations/grype_scan_repo/grype-scan-repo:latest -o -k -s "(Critical|High)"`


After the repositiory name, you can pass in normal arguments that you would pass to the shell script.  '-h' shows the help screen.  The '-v' volume bind allows you to map the code into the container to run it.

## Github Action usage
Coming Soon!
