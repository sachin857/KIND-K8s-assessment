# DevOps Challenge

## Overview

Create your own server with config of 4GB RAM, 4vCPU and 30GB storage.

I am not the owner or creator of this challenge. 

Owner repository link: https://github.com/elunic/elunic-challenge-devops/ 

## Rules

The only hard rules are:
1. You MAY NOT modify the Terraform code or the Kubernetes manifests that deploys the initial cluster, since it deploys in a way that sets up some of the tasks - BUT if the initial deployement fails, feel free to debug and fix it.

Otherwise, approach the task like you would for any other DevOps/infrastructure task, using your usual tools and apps. You may install anything you need on the server.


## Challenges

### Challenge 1

Deploy the Terraform stack in the `terraform` directory to create a KIND cluster on the target machine. Deploy the stack via SSH from your local machine. Debug any issues that might come up.

You now have the following environment:

1. the actual host-machine running linux - for cluster-external connections into kubernetes
2. and a 4-node KIND cluster running each of the kubernetes nodes as a docker container

You can restart the node-containers and work with them in any way you deem necessary.

The same is true for the host-machine itself. Again, you can install any tool you are missing and configure the machine in any way you see necessary to achieve the assignments below. Once you are done with the challenge, please properly exit all the sessions and close all the terminals you have been using.

You should use docker to connect into individual cluster-nodes running as containers - as you might have to run commands from inside the cluster but as a cluster node. Connecting to a pod inside the podCIDR of the cluster should work via kubectl commands as usual.

Ensure that your personal user account can run kubectl commandsTest it against the KIND cluster-context "kind-elunic-challenge" on the host machine

### Challenge 2

In the namespace "t2", you will find the deployment "task-2" with pods in a crash loop.Your task is to identify and fix the problems until the deployment "task-2" has two healthy replicas.

### Challenge 3

In the namespace "t3", you will find the deployment "task-3", containing a standard nginx server available at port 80.

**For this task, all modifications must be done using Terraform in new file called `terraform/task-3.tf` and then applying Terraform**.

* deploy a pod of your choice
   * **in the `default` namespace**.
   * with the label "role=http-client"
   * with an HTTP client (e.g., curl) installed inside it
* enter your newly created pod (manually, not via Terraform), and use curl to access the service "task-3" HTTP endpoint in the namespace "t3" (HTTP GET).
* it will not work, and you must identify and, **using resources you create in Terraform**, make sure your new pod can access the service "task-3" HTTP endpoint in the namespace "t3".

### Challenge 4

Start by creating the namespace "t4". Deploy a new pod with the following characteristic:

   - Image: gini/echochamber:latest
   - Name: echochamber
   - Container mode: privileged (to ease your debugging experience)
   - Don't change the entry point or command arguments

The echoChamber binary will write a secret message to an undisclosed location in the pod. *Note:* the string inside the binary itself is not the correct location.

- Use your debugging skills to identify:
  - **what** the secret message is
  - **where** it is written to
