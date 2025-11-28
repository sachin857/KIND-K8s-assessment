terraform {
  required_version = ">= 0.13.0"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

resource "null_resource" "dependencies" {
  connection {
    type        = "ssh"
    user        = var.ssh_username
    private_key = file(var.ssh_private_key_path)
    host        = var.ssh_host
    port        = var.ssh_port
  }

  provisioner "file" {
    source      = "../scripts/install-docker.sh"
    destination = "/tmp/install-docker.sh"
  }

  provisioner "file" {
    source      = "../scripts/install-kubectl.sh"
    destination = "/tmp/install-kubectl.sh"
  }

  provisioner "file" {
    source      = "../scripts/setup-kind.sh"
    destination = "/tmp/setup-kind.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-docker.sh && /tmp/install-docker.sh",
      "chmod +x /tmp/install-kubectl.sh && /tmp/install-kubectl.sh",
      "chmod +x /tmp/setup-kind.sh && /tmp/setup-kind.sh"
    ]
  }
}

resource "null_resource" "kind_cluster" {
  depends_on = [null_resource.dependencies]

  connection {
    type        = "ssh"
    user        = var.ssh_username
    private_key = file(var.ssh_private_key_path)
    host        = var.ssh_host
    port        = var.ssh_port
  }

  provisioner "file" {
    source      = "../kubernetes/kind-config.yaml"
    destination = "/tmp/kind-config.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "kind create cluster --name elunic-challenge --config /tmp/kind-config.yaml",
      "kubectl config use-context kind-elunic-challenge"
    ]
  }
}

resource "null_resource" "kubernetes_setup" {
  depends_on = [null_resource.kind_cluster]

  connection {
    type        = "ssh"
    user        = var.ssh_username
    private_key = file(var.ssh_private_key_path)
    host        = var.ssh_host
    port        = var.ssh_port
  }

  provisioner "file" {
    source      = "../kubernetes/coredns-configmap.yaml"
    destination = "/tmp/coredns-configmap.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "kubectl apply -f /tmp/coredns-configmap.yaml",
      "kubectl -n kube-system delete pods -l k8s-app=kube-dns",
      "sleep 20",
      "kubectl -n kube-system get pods -l k8s-app=kube-dns"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "kubectl create namespace t2 || true"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "kubectl create namespace t3 || true"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "kubectl delete deployment task-2 -n t2 --ignore-not-found=true",
      
      <<EOT
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: task-2
  namespace: t2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: task-2
  template:
    metadata:
      labels:
        app: task-2
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: task-2
            topologyKey: kubernetes.io/hostname
      containers:
      - name: nginx
        image: nginx:1.19
        resources:
          limits:
            memory: 1Ki
EOF
EOT
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "kubectl create deployment task-3 --image=nginx:1.19 -n t3 || true",
      "kubectl expose deployment task-3 --port=80 -n t3 || true",
      <<EOT
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: t3
spec:
  podSelector:
    matchLabels:
      app: task-3
  policyTypes:
  - Ingress
EOF
EOT
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "kubectl -n kube-system delete pods -l k8s-app=kube-dns",
      "sleep 10",
      
      "WORKER1_ID=$(docker ps --format '{{.ID}}' --filter name=elunic-challenge-worker$ | head -1)",
      "WORKER2_ID=$(docker ps --format '{{.ID}}' --filter name=elunic-challenge-worker2$ | head -1)",
      "WORKER3_ID=$(docker ps --format '{{.ID}}' --filter name=elunic-challenge-worker3$ | head -1)",
      "[ ! -z \"$WORKER1_ID\" ] && docker exec $WORKER1_ID systemctl is-active kubelet",
      "[ ! -z \"$WORKER2_ID\" ] && docker exec $WORKER2_ID systemctl is-active kubelet",
      "[ ! -z \"$WORKER3_ID\" ] && docker exec $WORKER3_ID systemctl is-active kubelet",
      
      "[ ! -z \"$WORKER1_ID\" ] && docker exec $WORKER1_ID bash -c 'echo \"nameserver 8.8.8.8\" >> /etc/resolv.conf'",
      "[ ! -z \"$WORKER2_ID\" ] && docker exec $WORKER2_ID bash -c 'echo \"nameserver 8.8.8.8\" >> /etc/resolv.conf'",
      "[ ! -z \"$WORKER3_ID\" ] && docker exec $WORKER3_ID bash -c 'echo \"nameserver 8.8.8.8\" >> /etc/resolv.conf'"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "kubectl label nodes elunic-challenge-worker3 gpu=a100 --overwrite",
      "kubectl cordon elunic-challenge-worker",
      "kubectl cordon elunic-challenge-worker2",
      "kubectl taint nodes elunic-challenge-control-plane node-role.kubernetes.io/control-plane:NoSchedule --overwrite",
    ]
  }
  
  provisioner "remote-exec" {
    inline = [
      "sleep 30",
      "kubectl delete pods --all -n t2 --grace-period=0 --force || true",
      "sleep 30",
      "kubectl get nodes",
      "kubectl get pods -n t2",
      "kubectl get networkpolicy -n t3"
    ]
  }
} 
