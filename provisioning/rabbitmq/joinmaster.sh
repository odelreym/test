#! /bin/bash

rabbitmqctl stop_app
rabbitmqctl join_cluster rabbit@$1
rabbitmqctl start_app
