# Ansible Vagrant Docker

## Background

[Docker](https://www.docker.com/) is used to build and manage linux containers. [Ansible](http://www.ansible.com/) is useful in managing the Docker container lifecycle.

This Vagrant profile uses Ansible to configure a local VM with Docker, then it uses Ansible to build and run 6 containers:

  - `redis`: a cluster of 2 redis containers (with persistence)
  - `rabbitmq`: a cluster of 2 rabbitmq containers (with persistence)
  - `mysql`: a Mysql master-slave replication (with persistence)

Vagrant --> Provision VM --> Execute ansible (main.yml) --> [ build docker containers --> start docker containers ]

```
.
├── README.md
├── Vagrantfile
├── provisioning
│   ├── containers.yml
│   ├── main.yml
│   ├── mysql
│   │   ├── Dockerfile
│   │   └── core
│   │       ├── init-slave.sh
│   │       └── replication-entrypoint.sh
│   ├── mysql.yml
│   ├── rabbitmq
│   │   ├── Dockerfile
│   │   └── joinmaster.sh
│   ├── rabbitmq.yml
│   ├── redis
│   │   └── Dockerfile
│   ├── redis.yml
│   └── setup.yml
└── requirements.yml
```

`main.yml` 

```
---
- hosts: all
  become: true

  pre_tasks:
    - name: Update apt cache if needed.
      apt: update_cache=yes cache_valid_time=3600

  roles:
    - role: geerlingguy.docker

  tasks:
    - import_tasks: setup.yml          #Install some pip requirements
    - import_tasks: containers.yml     #playbook for building the containers
    - import_tasks: redis.yml 
    - import_tasks: rabbitmq.yml
    - import_tasks: mysql.yml
```

## Getting Started

This README file is inside a folder that contains a `Vagrantfile` (hereafter this folder shall be called the [vagrant_root]), which tells Vagrant how to set up your virtual machine in VirtualBox.

To use the vagrant file, you will need to have done the following:

  1. `git clone` this repo
  2. Download and Install [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
  3. Download and Install [Vagrant](https://www.vagrantup.com/downloads.html)
  4. Install [Ansible](http://docs.ansible.com/ansible/latest/intro_installation.html)
  5. Run the following command to install the necessary Ansible roles for this profile: `$ ansible-galaxy install -r requirements.yml`

Once all of that is done, you can simply type in `vagrant up`, and Vagrant will create a new VM, install the base box, and configure it.

Once the new VM is up and running (after `vagrant up --provision` is complete and you're back at the command prompt), you can log into it via SSH if you'd like by typing in `vagrant ssh default`. 


```
root@docker:~# docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                                                                                                                                               NAMES
b4e90c9926b0        mysql               "/usr/local/bin/repl…"   7 minutes ago       Up 7 minutes        3306/tcp, 33060/tcp                                                                                                                                 mysql_slave
3b203009fbca        mysql               "/usr/local/bin/repl…"   7 minutes ago       Up 7 minutes        0.0.0.0:3306->3306/tcp, 33060/tcp                                                                                                                   mysql_master
8ca8dc4bbd97        rabbitmq            "docker-entrypoint.s…"   8 minutes ago       Up 8 minutes        5671/tcp, 15671/tcp, 0.0.0.0:4370->4369/tcp, 0.0.0.0:5673->5672/tcp, 0.0.0.0:15673->15672/tcp, 0.0.0.0:25673->25672/tcp, 0.0.0.0:35673->35672/tcp   rabbitmq-slave
1153998655be        rabbitmq            "docker-entrypoint.s…"   8 minutes ago       Up 8 minutes        0.0.0.0:4369->4369/tcp, 5671/tcp, 0.0.0.0:5672->5672/tcp, 0.0.0.0:15672->15672/tcp, 0.0.0.0:25672->25672/tcp, 0.0.0.0:35672->35672/tcp, 15671/tcp   rabbitmq-master
5ea149aa1955        redis:latest        "docker-entrypoint.s…"   8 minutes ago       Up 8 minutes        6379/tcp                                                                                                                                            redis-slave
f9f8bdbaa387        redis:latest        "docker-entrypoint.s…"   8 minutes ago       Up 8 minutes        0.0.0.0:6379->6379/tcp                                                                                                                              redis-master
```

Redis
```
root@docker:~# docker exec -it redis-slave redis-cli -h localhost info| grep -A3 Replication
# Replication
role:slave
master_host:redis-master
master_port:6379
```

RabbitMQ

 credentials are maintained into the Vagrantfile: `ansible.extra_vars`

```
root@docker:~# docker exec -it rabbitmq-01 rabbitmqctl cluster_status
Cluster status of node rabbit@rabbitmq-01 ...
[{nodes,[{disc,['rabbit@rabbitmq-01','rabbit@rabbitmq-02']}]},
 {running_nodes,['rabbit@rabbitmq-02','rabbit@rabbitmq-01']},
 {cluster_name,<<"rabbit@rabbitmq-01">>},
 {partitions,[]},
 {alarms,[{'rabbit@rabbitmq-02',[]},{'rabbit@rabbitmq-01',[]}]}]

```

Management RabbitMQ
```
root@docker:~# curl -I http://localhost:15672
HTTP/1.1 200 OK
content-length: 1391
content-type: text/html
date: Mon, 17 Feb 2020 01:15:15 GMT
etag: "821408888"
last-modified: Mon, 17 Feb 2020 00:59:21 GMT
server: Cowboy
``` 


Mysql
```
root@docker:~# docker exec -it mysql_slave mysql -uroot -pmysqlroot -e "SHOW SLAVE STATUS\G;"
mysql: [Warning] Using a password on the command line interface can be insecure.
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: mysql_master
                  Master_User: replication_user
                  Master_Port: 3306
                Connect_Retry: 60
```


Persistence
```
root@docker:~# tree -d /data/ -L 2
/data/
├── mysql
│   ├── master
│   └── slave
├── rabbitmq
│   ├── 1
│   └── 2
└── redis
    ├── master
    └── slave

```

## Add features/maintenance

You can extend the docker images (or add more functionality) by editing the Dockerfile in every service folder.
The ansible playbook builds the docker image everytime time is executed

## TODO
 
`wait_for`  ansible control should be fixed. It doesn't work nice in 2.9.5 running in MacOs
Ports can be forwarded to the host `config.vm.network "forwarded_port"`
All docker containers are deployed into a single VM. You can provision a VM per service by adapting the Vagranfile and the main.yml playbook
