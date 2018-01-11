#!/bin/bash

set -o errexit
set -o nounset
set -o xtrace

function setup_vpc(){
    vpc_id=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text)
    public_subnet=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.0.1.0/24 --query 'Subnet.SubnetId' --output text)
    gateway_id=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
    aws ec2 attach-internet-gateway --vpc-id $vpc_id --internet-gateway-id $gateway_id

    echo -e "{\"vpc_id\":\"$vpc_id\", \"public_subnet\":\"$public_subnet\", \"gateway_id\":\"$gateway_id\"}"
}

function create_route_tables(){
    public_rt=$(aws ec2 create-route-table --vpc-id $vpc_id --query 'RouteTable.RouteTableId' --output text)
    aws ec2 create-route --route-table-id $public_rt --destination-cidr-block 0.0.0.0/0 --gateway-id $gateway_id
    aws ec2 associate-route-table --route-table-id $public_rt --subnet-id $public_subnet

    echo -e "{\"public_rt\":\""$public_rt"\"}"

}

function create_security_groups(){
    sgid=$(aws ec2 create-security-group --group-name CLIGrp --description "My security group" --vpc-id $vpc_id --query 'GroupId' --output text)
    aws ec2 authorize-security-group-ingress --group-id $sgid --protocol tcp --port 22 --cidr 0.0.0.0/0
    aws ec2 authorize-security-group-ingress --group-id $sgid --protocol tcp --port 80 --cidr 0.0.0.0/0
    aws ec2 modify-subnet-attribute --subnet-id $public_subnet --map-public-ip-on-launch
    
    echo -e "{\"sgid\":\""$sgid"\"}"

}

function launch_instance(){
    instance_id=$(aws ec2 run-instances --image-id ami-a4827dc9 --count 1 --instance-type t2.micro --key-name geniekey --security-group-ids $sgid --subnet-id $public_subnet --query 'Instances[0].InstanceId' --output text)
    public_ip=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)
    instance_state=$(aws ec2 describe-instance-status --instance-id=$instance_id --query 'InstanceStatuses[0].InstanceState.Name' --output text)
    
    echo -e "{\"instance_id\":\""$instance_id"\", \"public_ip\":\""$public_ip"\", \"instance_state\":\""$instance_state"\"}"

}

function provision_aws(){
    #setup vpc
    vpc=$(setup_vpc)

    vpc_id=$(echo $vpc | jq '.vpc_id')
    public_subnet=$(echo $vpc | jq '.public_subnet')
    gateway_id=$(echo $vpc | jq '.gateway_id')

    #create route tables
    create_route_tables $vpc_id $public_subnet $gateway_id
    #create security groups
    security_group=$(create_security_groups $vpc_id $public_subnet)
    $sgid=$(echo $security_group | jq '.sgid')
    #launch instances
    instance=$(launch_instance $sgid $public_subnet)
    echo instance

}

function check_availability(){
    #run checks to find out the status of the provisioned instance
    echo 'checking'
}

function main(){
    # provision aws
    provision_aws
    # if instance is running, ssh into ec2 instance and install setup jenkins
    check_availability
}

main