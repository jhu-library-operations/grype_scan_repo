# grype_scan_repo
A wrapper around the grype command that should allow you to scan Dockerfiles or docker-compose.yml files for vulnerabilities in the base images.


```
./grype_scan_repo.sh: [-ci] [-h|--help]
        -c         Scan for docker-compose.yml files instead of Dockerfiles
        --dry-run  Does a dry run, doesn't pull images or scan.
        -i         Install grype into ~/bin/ and exit.
        -h|--help  Display this help.
```