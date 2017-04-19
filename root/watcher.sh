#!/bin/bash
export CONF_PATH=/etc/nginx/conf.d

function write_config() {
  prefix="$1"
  port="$2"
  host="$3"
  echo "Writing config for '$prefix' on port '$port'"
  cat <<END > $CONF_PATH/$prefix.docker.conf
server {
  server_name $prefix.bluebike.hosting;
  location / {
    proxy_pass       http://$host:$port;
    proxy_set_header Host            \$host;
    proxy_set_header X-Real-IP       \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  }
}
END
}

function regen_config() {
  cont_id="$1"
  host="$2"

  # Public port for contanier port 80
  port=$(docker port $cont_id 80 2>/dev/null | awk -F ':' '{print $2}')

  # If container doesn't have a port 80, we're done
  [ -n "$port" ] || return

  cont_name=$(docker inspect --format '{{.Name}}' $cont_id)
  cont_name=${cont_name:1}  # Strip the / off the front

  # Server prefix is everything before the first _
  # Example:
  #   > docker-compose -p 'test.lse' up
  #   > docker ps --format '{{.Names}}'
  #       test.lse_api_1
  #       test.lse_app_1
  #       ...
  #   This will result in a server prefix of `test.lse` (thus
  #   test.lse.bluebike.hosting)
  server_prefix=$(echo "$cont_name" | awk -F '_' '{ print $1 }')

  # Do it!
  write_config $server_prefix $port $host
}

function regen_configs {
  # Remove all old configs
  rm -f "$CONF_PATH"/*.docker.conf

  # Default router IP is the Docker host
  host=$(route | awk '$1 ~ /default/ {print $2}')

  # Try ang generate config for every container
  for cont_id in $(docker ps --all --format '{{.ID}}'); do
    regen_config "$cont_id" "$host"
  done
}

function process() {
  regen_configs
  nginx -s reload
}

function process_line {
  # Limit the lines that we process to container create and destroy events
  cont_id=$(echo "$1" | awk '$2 ~ /container/ && $3 ~ /destroy|create/ { print $4 }')
  [ -n "$cont_id" ] || return
  process
}

process

while read line; do
  process_line "$line"
done
