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
  port=$(docker port $cont_id 80 2>/dev/null | awk -F ':' '{print $2}')
  [ -n "$port" ] || return
  cont_name=$(docker inspect --format '{{.Name}}' $cont_id)
  cont_name=${cont_name:1}
  server_prefix=$(echo "$cont_name" | awk -F '_' '{ print $1 }')
  write_config $server_prefix $port $host
}

function regen_configs {
  rm -f "$CONF_PATH"/*.docker.conf
  host=$(route | awk '$1 ~ /default/ {print $2}')
  for cont_id in $(docker ps --all --format '{{.ID}}'); do
    regen_config "$cont_id" "$host"
  done
}

function process() {
  regen_configs
  nginx -s reload
}

function process_line {
  cont_id=$(echo "$1" | awk '$2 ~ /container/ && $3 ~ /destroy|create/ { print $4 }')
  [ -n "$cont_id" ] || return
  process
}

process

while read line; do
  process_line "$line"
done
