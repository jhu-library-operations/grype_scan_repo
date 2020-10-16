# grype_scan_repo
A wrapper around the grype command that should allow you to scan Dockerfiles or docker-compose.yml files for vulnerabilities in the base images.


```
./grype_scan_repo.sh: [-ci] [-h|--help]
        -c         Scan for docker-compose.yml files instead of Dockerfiles
        -i         Install grype into ~/bin/ and exit.
        -h|--help  Display this help.
```

## Installation
I find it easiest to download a copy of the shell script to ~/bin/ and make sure that ~/bin/ is in my $PATH.  If you don't already have grype, you can grab it with the `-i` flag.

**Note:** The latest released version of grype does not include a fix for the syft library and some Alpine packages.  If you use the `-i` option, it will download and build a version that will work.
