
# 📘 Program Runbook for task #3

## 🧩 Overview
this Flask Application provide you ssh logs analyze

## 🚀 How to Run

### Prerequisites
- VirtualBox (better 6.1)
- Vagrant
- 3 pairs of ed25519 keys (temp)

### Setup
- copy files from task3 directory to your folder
- copy your ed25519 keys to share folder `(so machines can use them)` rename them to next format: `sftpN_ed25519` and `sftpN_ed25519.pub` where N - number of pair (1, 2 or 3)  `##(temp)##`
- open terminal in your folder and write:
```bash
vagrant up
```
- after all machines installed write:
```bash
vagrant halt alpine
vagrant up alpine
```
- write:
``` bash
vagrant ssh alpine
```
- change user to appuser (default password: 123)
- start script `/home/appuser/scripts/alpine_ssh.sh` to add other machines to known_hosts
- start script `/home/appuser/scripts/get_logs.sh` to manually read logs
- go to directory `/home/appuser/app/` and start the application by next command:
```bash
docker-compose up --build -d
```
- all is done just check http://localhost:5000/
### Additional
- you can change password for sftpuser and appuser inside share folder just change file `password`, default password = 123
