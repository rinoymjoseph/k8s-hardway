192.168.0.145   86:AC:41:36:AD:BE   terraform
192.168.0.149   86:AC:41:71:70:7D   k8s-bootstrap
192.168.0.150   86:AC:41:4C:4B:A2   k8s-controllers-lb
192.168.0.151   86:AC:41:B6:DC:C2   k8s-controller-1
192.168.0.152   86:AC:41:C6:28:10   k8s-controller-2
192.168.0.153   86:AC:41:E3:4E:20   k8s-controller-3
192.168.0.161   86:AC:41:A9:79:16   k8s-worker-1
192.168.0.162   86:AC:41:FD:2E:4F   k8s-worker-2
192.168.0.163   86:AC:41:01:23:30   k8s-worker-3

echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
sudo visudo -c

sudo apt update
sudo apt install software-properties-common unzip sshpass python3-pip -y
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible
pip3 install kubernetes

sudo apt update
sudo apt install ansible-core python3-pip unzip sshpass -y
python3 -m pip install --upgrade --user ansible
sudo reboot
ansible-galaxy collection install community.general ansible.posix
