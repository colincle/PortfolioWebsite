# Web server image for clementcolin.com.
# Built from a base Alpine image and nginx installed by hand, rather than the
# prebuilt nginx image, so every layer is explicit and auditable (same approach
# as the inception project).

FROM alpine:3.21

# nginx is the only dependency: it serves the static site.
RUN apk add --no-cache nginx

# The alpine nginx package writes its pid to /run/nginx but does not create the
# directory, so nginx -g 'daemon off;' would fail to start without this.
RUN mkdir -p /run/nginx

# The site files and the nginx config are bind-mounted at runtime
# (see docker-compose.yml), so nothing is baked into the image and no secret
# ever lands in a layer.

EXPOSE 80

# Foreground so the container stays alive and Docker can supervise/restart it.
CMD ["nginx", "-g", "daemon off;"]
