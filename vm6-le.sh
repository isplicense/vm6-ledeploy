#/bin/bash
# Renew hook script to deploy Let's Encrypt cert to VM6 through API.
#
# USER_ID from vmmanager with admin rights
USER_ID=1

KEY=$(docker exec vm_box curl -s -k -X POST http://input:1500/auth/v4/user/$USER_ID/key -d '{}' -H 'internal-auth:on' | jq '{"key": .key}')
[[ "$KEY" == "null" ]] && exit 1

SESSION=$(curl -s -k https://localhost/auth/v4/public/key -H "isp-box-instance: true" -d "$KEY" -k | jq -s -r .[].token)
[[ "$SESSION" == "null" ]] && exit 1

PAYLOAD=$(jq --arg certificate "$(<$RENEWED_LINEAGE/cert.pem)" --arg ca_bundle "$(<$RENEWED_LINEAGE/chain.pem)" --arg private_key "$(<$RENEWED_LINEAGE/privkey.pem)" \
             '{"name":"ssl_cert","certificate":$certificate,"ca_bundle":$ca_bundle,"private_key":$private_key}' <<< '{}')

RESULT=$(curl --write-out %{http_code} "https://localhost/nginxctl/v1/ssl" -H "Cookie: ses6=$SESSION" -d "$PAYLOAD" -s -k)

[[ "$RESULT" != "200" ]] && exit 1

exit 0
