#!/bin/sh

kong="http://apigw:8001"

# check if kong is started
if curl --output /dev/null --silent --head --fail "$kong"; then
  echo "Kong is started."
else
  echo "Kong isn't started."
  echo "Terminating in 20s..."
  sleep 20
  exit 1
fi

# add authentication to an endpoint
addAuthToEndpoint() {
# $1 = Service Name
echo ""
echo ""
echo "- addAuthToEndpoint: ServiceName=${1}, RoleRequiredToAccess=${2}"

if [ "$2" != "" ]; then
  curl -X POST ${kong}/services/"${1}"/plugins \
    --data "name=jwt-keycloak" \
    --data "config.allowed_iss=http://keycloak:8080/auth/realms/master" \
    --data "config.client_roles=${1}:admin" \
    --data "config.client_roles=${1}:${2}"
else
  curl -X POST ${kong}/services/"${1}"/plugins \
    --data "name=jwt-keycloak" \
    --data "config.allowed_iss=http://keycloak:8080/auth/realms/master" \
    --data "config.client_roles=${1}:admin"
fi

}


# add a Service
# that is the name Kong uses to refer to the upstream APIs
# and microservices it manages.
createService() {
# $1 = Service Name
# $2 = URL (ex.: http://gui:80)
echo ""
echo "-- createService: ServiceName=${1} Url=${2}"
curl  -sS -X PUT \
--url ${kong}/services/"${1}" \
--data "name=${1}" \
--data "url=${2}"
}

# add a Route
# The Route represents the actual request to the Kong proxy
# endpoint to reach at Kong service.
createRoute() {
# $1 = Service Name
# $2 = Route Name
# $3 = PATHS (ex.: '"/","/x"')
# $4 = strip_path (true or false), When matching a Route via one of the paths, strip the matching prefix from the upstream request URL
echo ""
echo "-- createRoute: ServiceName=${1} Url=${2} PathS=${3} StripPath=${4}"
(curl  ${kong}/services/"${1}"/routes/"${2}" -sS -X PUT \
    --header "Content-Type: application/json" \
    -d @- ) <<PAYLOAD
{
    "paths": [${3}],
    "strip_path": ${4}
}
PAYLOAD
}

# Create an endpoint mapping in Kong
# ex1: createEndpoint "data-broker" "http://data-broker:80"  '"/device/(.*)/latest", "/subscription"' "false"
# ex2: createEndpoint "image" "http://image-manager:5000"  '"/fw-image"' "true"
createEndpoint(){
# $1 = Service Name
# $2 = URL (ex.: "http://gui:80")
# $3 = PATHS (ex.: '"/","/x"')
# $4 = strip_path ("true" or "false"), When matching a Route via one of the paths, strip the matching prefix from the upstream request URL.
echo ""
echo ""
echo "- createEndpoint: ServiceName=${1} Url=${2} PathS=${3} StripPath=${4}"
createService "${1}" "${2}"
createRoute "${1}" "${1}_route" "${3}" "${4}"
}

# service: gui

createEndpoint "gui" "http://gui:80"  '"/"' "false"

# service: data-broker

createEndpoint  "data-broker" "http://data-broker:80"  '"/device/(.*)/latest", "/subscription"' "false"
addAuthToEndpoint "data-broker" "user"

createEndpoint "data-streams" "http://data-broker:80"  '"/stream"' "true"
addAuthToEndpoint "data-streams" "user"

createEndpoint "ws-http" "http://data-broker:80"  '"/socket.io"' "false"

# service: device-manager

createEndpoint "device-manager" "http://device-manager:5000"  '"/device", "/template"' "false"
addAuthToEndpoint "device-manager"

# service: image-manager

createEndpoint "image" "http://image-manager:5000"  '"/fw-image"' "true"
addAuthToEndpoint "image" "user"

# service: auth

createEndpoint "auth-service" "http://keycloak:8080/auth"  '"/auth"' "true"
echo ""
echo ""
echo "- add plugin rate-limiting in auth-service"
curl  -s  -sS -X POST \
--url ${kong}/services/auth-service/plugins/ \
--data "name=rate-limiting" \
--data "config.minute=5" \
--data "config.hour=40" \
--data "config.policy=local"

# service: flowbroker

createEndpoint "flows" "http://flowbroker:80"  '"/flows"' "true"
addAuthToEndpoint "flows" "user"

createEndpoint "flowsIcons" "http://flowbroker:80/icons"  '"/flows/icons"' "true"

createEndpoint "flowsRedImages" "http://flowbroker:80/red/images"  '"/flows/red/images"' "true"

# service: history

createEndpoint "history" "http://history:8000"  '"/history"' "true"
addAuthToEndpoint "history" "user"

# service: ejbca

createEndpoint "ejbca-paths" "http://ejbca:5583/"  '"/sign", "/ca", "/user"' "false"
addAuthToEndpoint "ejbca-paths" "user"

# service: data-manager

createEndpoint "data-manager" "http://data-manager:3000/"  '"/export", "/import"' "false"
addAuthToEndpoint "data-manager" "user"

# service: backstage

createEndpoint "backstage_graphql" "http://backstage:3005/"  '"/graphql(.*)"' "false"

# service: cron

createEndpoint "cron" "http://cron:5000/"  '"/cron"' "false"
addAuthToEndpoint "cron" "user"

