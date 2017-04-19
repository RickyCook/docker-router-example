FROM nginx:alpine

RUN apk add --no-cache bash docker
ADD root/ /

CMD ["/runall.sh"]
