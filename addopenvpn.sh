###################################################################
# File Name: addopenvpn.sh
# Author: mancheng.shi
#==================================================================
#!/bin/bash

#vens
check=$1
vpn_user=$2

#check docker
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

#docker config
docker_conf()
{
cat >/etc/docker/daemon.json <<EOF
{
"registry-mirrors": ["https://9tf8kvxw.mirror.aliyuncs.com"]
}
EOF
systemctl start docker
systemctl enable docker
docker pull kylemanna/openvpn:2.4
mkdir -p /data/openvpn/conf
}


vpn_config()
{
#create config file
read -p "请输入公网IP（Input IP）: " ip
docker run -v /data/openvpn:/etc/openvpn --rm kylemanna/openvpn:2.4 ovpn_genconfig -u udp://${ip}
#生成密钥文件
cat <<EOF
===========================================<重要信息提示>======================================
1、输入私钥密码（输入时不可见，根据实际情况输入，例如s68s668）：
>Enter PEM pass phrase:
2、再输入一遍
>Verifying - Enter PEM pass phrase:
3、输入一个CA名称（根据实际情况输入，例如myca，也可以直接回车）
>Common Name (eg: your user, host, or server name) [Easy-RSA CA]:
4、输入刚才设置的私钥密码（输入完成后会再让输入一次）
>Enter pass phrase for /etc/openvpn/pki/private/ca.key:
==============================================================================================
EOF
docker run -v /data/openvpn:/etc/openvpn --rm -it kylemanna/openvpn:2.4 ovpn_initpki
# run openvpn
docker run --name openvpn -v /data/openvpn:/etc/openvpn -d -p 1194:1194/udp --cap-add=NET_ADMIN kylemanna/openvpn:2.4
}

# install VPN
install_vpn()
{
docker_check
vpn_config
name=$(docker ps |awk '/openvpn/ {print $NF}')
if [ "$name" = "openvpn" ];then
touch /data/openvpn/openvpn.lock
cp -rf ./openvpn.sh /usr/local/bin/openvpn
cat <<EOF
================================================<成功提示>===============================================
Openvpn 已安装成功，请创建用户后使用!（successful）
========================================================================================================
EOF
else
cat <<EOF
================================================<错误提示>================================================
Openvpn 安装失败，请检查后操作!(error)
EOF
exit 1
fi
}

#删除VPN用户
vpn_del_user()
{
# read -p "请输入删除的用户名: " vpn_user
docker run -v /data/openvpn:/etc/openvpn --rm -it kylemanna/openvpn:2.4 easyrsa revoke ${vpn_user}
docker run -v /data/openvpn:/etc/openvpn --rm -it kylemanna/openvpn:2.4 easyrsa gen-crl
docker run -v /data/openvpn:/etc/openvpn --rm -it kylemanna/openvpn:2.4 rm -f /etc/openvpn/pki/reqs/"${vpn_user}".req
docker run -v /data/openvpn:/etc/openvpn --rm -it kylemanna/openvpn:2.4 rm -f /etc/openvpn/pki/private/"${vpn_user}".key
docker run -v /data/openvpn:/etc/openvpn --rm -it kylemanna/openvpn:2.4 rm -f /etc/openvpn/pki/issued/"${vpn_user}".crt
docker restart openvpn
echo "================================================<成功提示>================================================"
echo " 注销并已删除vpn用户:${vpn_user}成功!（del successful）"
echo "=========================================================================================================="
}

#添加VPN用户
vpn_add_user()
{
# read -p "请输入添加新的用户名: " vpn_user
if [ -e "/data/openvpn/conf/${vpn_user}.ovpn" ];then
echo "================================================<温馨提示>================================================"
echo "VPN用户：${vpn_user}已存在,请检查后操作!!(error repeat user )"
echo "========================================================================================================="
else
docker run -v /data/openvpn:/etc/openvpn --rm -it kylemanna/openvpn:2.4 easyrsa build-client-full ${vpn_user} nopass
docker run -v /data/openvpn:/etc/openvpn --rm kylemanna/openvpn:2.4 ovpn_getclient ${vpn_user} > /data/openvpn/conf/${vpn_user}.ovpn
docker restart openvpn
cat <<EOF
================================================<成功提示>=================================================
新建vpn用户:${vpn_user}成功!（create successful）"
=========================================================================================================
新建vpn用户:${vpn_user} 密钥已生成在/data/openvpn/conf/${vpn_user}.ovpn ，请自行获取！！！"
==========================================================================================================
EOF
fi
}


help()
#帮助函数
{
cat <<EOF
================================================<帮助提示>================================================
添加vpn用户执行命令: openvpn add vpn用户名
删除vpn用户执行命令: openvpn del vpn用户名
安装VPN执行命令:openvpn.sh install
=========================================================================================================
EOF
}


main()
{

if [ "${check}" = "add" ];then
vpn_add_user
elif [ "${check}" = "install" ];then
if [ ! -e /data/openvpn/openvpn.lock ];then
install_vpn
else
echo "================================================<信息提示>================================================"
echo "Openvpn已经安装，请检查后操作!"
exit 1
fi
elif [ "${check}" = "del" ];then
vpn_del_user
else
echo "================================================<错误提示>================================================"
echo " 输入参数类型无效,类型只包含add|install|del"
help
fi
}

main