#cloud-config
packages:
 - curl
 - awscli
perserve_hostname: true
runcmd:
# get region
 - export AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')
# setup awscli
 - mkdir -p /root/.aws
 - echo "[default]\nregion=$AWS_REGION" | tee /root/.aws/config
# get instance name
 - export FQDN=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" "Name=key,Values=Name" --output=text | cut -f 5)
# set hostname
 - hostnamectl set-hostname --static $FQDN
