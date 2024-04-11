#/bin/bash
# Renew hook script to deploy Let's Encrypt cert to VM6 through API.
#
# USER_ID from vmmanager with admin rights
USER_ID="1"
CERT_PATH="$RENEWED_LINEAGE" #/etc/letsencrypt/live/domain.com

RETRY=0
while [[ true ]]
do
    KEY_RESULT=$(docker exec vm_box curl -s -k -X POST http://input:1500/auth/v4/user/$USER_ID/key -d '{}' -H 'internal-auth:on')
    KEY=$(jq -r .key <<< $KEY_RESULT)

    [[ $? -eq 0 ]] && [[ "$KEY" != "null" && ! -z "$KEY" ]] && break

    ((RETRY++)) && ((RETRY==10)) && echo "API Error: auth/v4/user/$USER_ID/key" && exit 1
    sleep 1
done

RETRY=0
while [[ true ]]
do
    SESSION_RESULT=$(curl -s -k https://localhost/auth/v4/public/key -H "isp-box-instance: true" -d "{\"key\": \"$KEY\"}")
    SESSION=$(jq -r .token <<< $SESSION_RESULT)

    [[ $? -eq 0 ]] && [[ "$SESSION" != "null" && ! -z "$SESSION" ]] && break

    ((RETRY++)) && ((RETRY==10)) && echo "API Error: auth/v4/public/key" && exit 1
    sleep 1
done

[[ ! -f "$CERT_PATH/cert.pem" || ! -f "$CERT_PATH/chain.pem" || ! -f "$CERT_PATH/privkey.pem" ]] && echo "Error: Certificates not found" && exit 1

PAYLOAD=$(jq --arg certificate "$(<$CERT_PATH/cert.pem)" --arg ca_bundle "$(<$CERT_PATH/chain.pem)" --arg private_key "$(<$CERT_PATH/privkey.pem)" \
             '{"name":"ssl_cert","certificate":$certificate,"ca_bundle":$ca_bundle,"private_key":$private_key}' <<< '{}')

RETRY=0
while [[ true ]]
do
    PAYLOAD_RESULT=$(curl --write-out %{http_code} -s -k "https://localhost/nginxctl/v1/ssl" -H "Cookie: ses6=$SESSION" -H "x-xsrf-token: $SESSION" -d "$PAYLOAD")

    [[ "$PAYLOAD_RESULT" == "200" ]] && break

    ((RETRY++)) && ((RETRY==10)) && echo "API Error: nginxctl/v1/ssl" && exit 1
    sleep 1
done

echo "Success."

exit 0
