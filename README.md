# grype_scan_repo
A wrapper around the grype command that should allow you to scan Dockerfiles or docker-compose.yml files for vulnerabilities in the base images.


```
./grype_scan_repo.sh: [-ci] [-h|--help]
        -c         Scan for docker-compose.yml files instead of Dockerfiles
        -k         Scan for *.yml and *.yaml files (kubernetes) 
        --dry-run  Does a dry run, doesn't pull images or scan.
        -o         Show the vulnerablility output on stdout
        -i         Install grype and crane into ~/bin/ and exit.
        -h|--help  Display this help.
```

## Installation
I find it easiest to download a copy of the shell script to ~/bin/ and make sure that ~/bin/ is in my $PATH.  If you don't already have grype, you can grab it with the `-i` flag.

## Docker usage
You can also use this as a container.  You can use a command like this:
`# docker pull ghcr.io/jhu-library-operations/grype_scan_repo/grype-scan-repo:latest`

Once you have the image locally, you can run it like this:
`docker run -it -v /home/user/projects/repo-to-scan/:/tmp/code grype-scan-repo:latest -o -k -s "(Critical|High)"`
After the repositiory name, you can pass in normal arguments that you would pass to the shell script.  '-h' shows the help screen.  The '-v' volume bind allows you to map the code into the container to run it.
