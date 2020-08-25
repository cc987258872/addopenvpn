#!/bin/bash

docker_check()
{
docker_dpkg=$(dpkg -l |grep docker |wc -l)
if [ ${docker_dpkg} -gt 0 ];then
echo "docker is already installed"
docker_conf
else
sudo apt-get update
sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get -y update
sudo apt-get -y install docker-ce
docker_conf
fi
}

main()
{
    docker_check
}

main