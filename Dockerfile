FROM alpine:3

RUN apk add --no-cache go git

COPY grype_scan_repo.sh  /bin/grype_scan_repo.sh
RUN chmod +x /bin/grype_scan_repo.sh
RUN HOME=/ /bin/grype_scan_repo.sh -i
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]