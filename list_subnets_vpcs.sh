REGIONS=("us-east-1")

for region in "${REGIONS[@]}"; do
    VPCS=$(aws ec2 describe-vpcs --region $region | jq -c '.Vpcs[] | {VpcId, CidrBlock}')
    SUBNETS=$(aws ec2 describe-subnets --region $region | jq -c  '.Subnets[] | {SubnetId, CidrBlock, VpcId, MapPublicIpOnLaunch}')

    declare -a VPC_LIST
    declare -A VPC_SUBNETS

    while IFS= read -r vpc; do
        VPC_LIST+=("$vpc")
        VPC_ID=$(echo $vpc | jq -r '.VpcId')
        VPC_SUBNETS["$VPC_ID"]='[]'  
    done <<< "$VPCS"

    while IFS= read -r subnet; do
        SUBNET_VPC_ID=$(echo $subnet | jq -r '.VpcId')
        subnet=$(echo "$subnet" | jq 'del(.VpcId)')
        VPC_SUBNETS["$SUBNET_VPC_ID"]=$(echo "${VPC_SUBNETS["$SUBNET_VPC_ID"]}" | jq -c ". + [$subnet]")
    done <<< "$SUBNETS"

    for vpc in "${VPC_LIST[@]}"; do
        VPC_ID=$(echo $vpc | jq -r '.VpcId')
        CIDR_BLOCK=$(echo $vpc | jq -r '.CidrBlock')

        RESULT=$(jq -n \
            --arg vpcId "$VPC_ID" \
            --arg cidrBlock "$CIDR_BLOCK" \
            --argjson subnets "${VPC_SUBNETS["$VPC_ID"]}" \
            '{
                "VpcId": $vpcId,
                "CidrBlock": $cidrBlock,
                "Subnets": $subnets
            }')

        echo "$RESULT" >> $region.json
    done
done