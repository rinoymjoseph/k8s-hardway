86:AC:41:78:FD:0A 192.168.0.164
86:AC:41:01:23:30 192.168.0.163 - k8s-worker-3
86:AC:41:FD:2E:4F 192.168.0.162 - k8s-worker-2
86:AC:41:A9:79:16 192.168.0.161 - k8s-worker-1
86:AC:41:50:32:FB 192.168.0.160
86:AC:41:04:34:A0 192.168.0.159
86:AC:41:99:5C:6E 192.168.0.158
86:AC:41:F1:1D:1C 192.168.0.157
86:AC:41:6A:01:6C 192.168.0.156
86:AC:41:9C:DA:28 192.168.0.155
86:AC:41:66:FD:B1 192.168.0.154
86:AC:41:E3:4E:20 192.168.0.153 - k8s-controller-3
86:AC:41:C6:28:10 192.168.0.152 - k8s-controller-2
86:AC:41:B6:DC:C2 192.168.0.151 - k8s-controller-1
86:AC:41:4C:4B:A2 192.168.0.150 - k8s-controllers-lb
86:AC:41:71:70:7D 192.168.0.149 - k8s-bootstrap
86:AC:41:AF:EC:2B 192.168.0.148 - k3s-agent-1
86:AC:41:D7:CF:7B 192.168.0.147 - k3s-master
86:AC:41:03:C2:7B 192.168.0.146
86:AC:41:36:AD:BE 192.168.0.145
86:AC:41:55:07:F2 192.168.0.144
86:AC:41:98:04:17 192.168.0.143
86:AC:41:3F:AD:DD 192.168.0.142

sudo apt update
sudo apt install ansible-core python3-pip unzip sshpass -y
python3 -m pip install --upgrade --user ansible
sudo reboot
ansible-galaxy collection install community.general ansible.posix
