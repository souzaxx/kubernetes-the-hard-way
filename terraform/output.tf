output k_04_01_certificate_authority {
  value = <<OUTPUT

{

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

}

OUTPUT
}

output k_04_02_client_and_server_certificates {
  value = <<OUTPUT

{

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

}

OUTPUT
}

output k_04_03_the_controller_manager_client_certificate {
  value = <<OUTPUT

{

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

}

OUTPUT
}

output k_04_04_the_kubelet_client_certificates {
  value = <<OUTPUT

for instance in {1..${module.k8s_controllers.instance_count}}; do
instance_name=worker-$instance
cat > $instance_name-csr.json <<EOF
{
  "CN": "system:node:$instance_name",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

INTERNAL_IP=(${join(" ", module.k8s_workers.private_ip)})

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=$instance_name,$INTERNAL_IP[($instance)] \
  -profile=kubernetes \
  $instance_name-csr.json | cfssljson -bare $instance_name
done
OUTPUT
}

output k_04_05_the_kube_proxy_client_certificate {
  value = <<OUTPUT

{

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

}
OUTPUT

}


output k_04_06_the_scheduler_client_certificate {
  value = <<OUTPUT

{

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

}

OUTPUT
}

output k_04_07_the_kubernetes_api_server_certificate {
  value = <<OUTPUT

{

KUBERNETES_PUBLIC_ADDRESS=${module.elb.this_elb_dns_name}

KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,${join(",", module.k8s_controllers.private_ip)},$KUBERNETES_PUBLIC_ADDRESS,127.0.0.1,$KUBERNETES_HOSTNAMES \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

}
OUTPUT
}

output k_04_08_the_service_account_key_pair {
  value = <<OUTPUT

{

cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

}

OUTPUT
}


output k_04_09_distribute_the_client_and_server_certificates {
  value = <<OUTPUT

INSTANCE_ID=(${join(" ", module.k8s_workers.id)})

for instance in {1..${module.k8s_workers.instance_count}}; do
  scp -i terraform/kubernetes.pem ca.pem worker-$instance-key.pem worker-$instance.pem ubuntu@$INSTANCE_ID[($instance)]:~/
done

INSTANCE_ID=(${join(" ", module.k8s_controllers.id)})

for instance in {1..${module.k8s_controllers.instance_count}}; do
  scp -i terraform/kubernetes.pem ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem ubuntu@$INSTANCE_ID[($instance)]:~/
done

OUTPUT
}


output k_05_01_the_kubelet_kubernetes_configuration_file {
  value = <<OUTPUT

KUBERNETES_PUBLIC_ADDRESS=${module.elb.this_elb_dns_name}

for instance in {1..${module.k8s_workers.instance_count}}; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://$KUBERNETES_PUBLIC_ADDRESS:6443 \
    --kubeconfig=worker-$instance.kubeconfig

  kubectl config set-credentials system:node:worker-$instance \
    --client-certificate=worker-$instance.pem \
    --client-key=worker-$instance-key.pem \
    --embed-certs=true \
    --kubeconfig=worker-$instance.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:worker-$instance \
    --kubeconfig=worker-$instance.kubeconfig

  kubectl config use-context default --kubeconfig=worker-$instance.kubeconfig
done
OUTPUT
}

output k_05_02_the_kube_proxy_kubernetes_configuration_file {
  value = <<OUTPUT

KUBERNETES_PUBLIC_ADDRESS=${module.elb.this_elb_dns_name}

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://$KUBERNETES_PUBLIC_ADDRESS:6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=kube-proxy.pem \
  --client-key=kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

OUTPUT
}

output k_05_03_the_kube_controller_manager_kubernetes_configuration_file {
  value = <<OUTPUT

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=kube-controller-manager.pem \
  --client-key=kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

OUTPUT
}

output k_05_04_the_kube_scheduler_kubernetes_configuration_file {
  value = <<OUTPUT

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=kube-scheduler.pem \
  --client-key=kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
OUTPUT
}

output k_05_05_the_admin_kubernetes_configuration_file {
  value = <<OUTPUT

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig
OUTPUT
}

output k_05_06_distribute_the_kubernetes_configuration_files {
  value = <<OUTPUT

WORKER_INSTANCE_IDS=(${join(" ", module.k8s_workers.id)})
CONTROLLER_INSTANCE_IDS=(${join(" ", module.k8s_controllers.id)})

for instance in {1..${module.k8s_workers.instance_count}}; do
  scp -i terraform/kubernetes.pem ca.pem worker-$instance.kubeconfig\
    kube-proxy.kubeconfig ubuntu@$WORKER_INSTANCE_IDS[($instance)]:~/
done

for instance in {1..${module.k8s_controllers.instance_count}}; do
  scp -i terraform/kubernetes.pem admin.kubeconfig kube-controller-manager.kubeconfig\
    kube-scheduler.kubeconfig ubuntu@$CONTROLLER_INSTANCE_IDS[($instance)]:~/
done

OUTPUT
}

output k_06_01_encryption_config_file {
  value = <<OUTPUT

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
CONTROLLER_INSTANCE_IDS=(${join(" ", module.k8s_controllers.id)})

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: $ENCRYPTION_KEY
      - identity: {}
EOF

for instance in {1..${module.k8s_controllers.instance_count}}; do
  scp -i terraform/kubernetes.pem encryption-config.yaml\
    ubuntu@$CONTROLLER_INSTANCE_IDS[($instance)]:~/
done
OUTPUT
}

output connection_controllers {
  value = <<EOF
    xpanes -t -s -c "ssh -o StrictHostKeyChecking=no -i terraform/kubernetes.pem ubuntu@{}" \
      ${join(" ", module.k8s_controllers.id)}
  EOF
}

output connection_workers {
  value = <<EOF

    xpanes -t -s -c "ssh -o StrictHostKeyChecking=no -i terraform/kubernetes.pem ubuntu@{}" \
      ${join(" ", module.k8s_workers.id)}
  EOF
}

resource "local_file" "private_key" {
  sensitive_content = tls_private_key.this.private_key_pem
  filename          = "${path.module}/${aws_key_pair.this.key_name}.pem"
  file_permission   = "600"
}
