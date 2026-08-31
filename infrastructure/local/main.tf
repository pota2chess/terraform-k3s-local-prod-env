terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  endpoints {
    sts = "http://localhost:4566"
    iam = "http://localhost:4566"
    s3  = "http://localhost:4566"
    ec2 = "http://localhost:4566"
  }
}

provider "docker" {}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

# Create custom docker's network
resource "docker_network" "dev-net" {
  name = "dev-net"
}
# Gitea
resource "docker_image" "gitea" {
  name         = "gitea/gitea:latest"
  keep_locally = true
}

resource "docker_container" "gitea" {
  image = docker_image.gitea.image_id
  name  = "gitea"
  networks_advanced {
    name = docker_network.dev-net.name
  }
  volumes {
    container_path = "/var/lib/gitea"
    host_path      = "/mount/gitea/data"
  }
  volumes {
    container_path = "/etc/gitea"
    host_path      = "/mount/gitea/config"
  }
  ports {
    internal = 3000
    external = 3000
  }
  ports {
    internal = 22
    external = 2222
  }
}

# Prometheus
resource "docker_image" "prometheus" {
  name         = "prom/prometheus:latest"
  keep_locally = true
}

resource "docker_container" "prometheus" {
  image = docker_image.prometheus.image_id
  name  = "prometheus"
  networks_advanced {
    name = docker_network.dev-net.name
  }
  ports {
    internal = 9090
    external = 9090
  }
}

# Grafana
resource "docker_image" "grafana" {
  name         = "grafana/grafana:nightly-ubuntu"
  keep_locally = true
}

resource "docker_container" "grafana" {
  image = docker_image.grafana.image_id
  name  = "grafana"
  networks_advanced {
    name = docker_network.dev-net.name
  }
  ports {
    internal = 3000
    external = 3001
  }
}

# LoKi
resource "docker_image" "loki" {
  name         = "grafana/loki:main-34de7e2"
  keep_locally = true
}

resource "docker_container" "loki" {
  image = docker_image.loki.image_id
  name  = "loki"
  networks_advanced {
    name = docker_network.dev-net.name
  }
  ports {
    internal = 3100
    external = 3100
  }
}

resource "local_file" "k3s_registries" {
  filename = "${path.module}/registries.yaml"
  content  = <<EOT
mirrors:
  "registry:5000":
    endpoint:
      - "http://registry:5000"
EOT
}

# k3s
resource "docker_image" "k3s" {
  name         = "rancher/k3s:v1.36.4-rc1-k3s1"
  keep_locally = true
}

resource "docker_container" "k3s" {
  image      = docker_image.k3s.image_id
  name       = "k3s"
  command    = ["server"]
  privileged = true
  networks_advanced {
    name = docker_network.dev-net.name
  }
  ports {
    internal = 6443
    external = 6443
  }
  ports {
    internal = 8080
    external = 8080
  }
  volumes {
    host_path      = abspath(local_file.k3s_registries.filename)
    container_path = "/etc/rancher/k3s/registries.yaml"
    read_only      = true
  }

  provisioner "local-exec" {
    command = <<EOT
      until docker exec k3s test -f etc/rancher/k3s/k3s.yaml; do
        echo "Waiting create k3s.yaml"
        sleep 1
      done
      docker cp k3s:etc/rancher/k3s/k3s.yaml ~/.kube/config
    EOT
  }
}

# Localstack
resource "docker_image" "localstack" {
  name         = "localstack/localstack:latest"
  keep_locally = true
}

resource "docker_container" "localstack" {
  image = docker_image.localstack.image_id
  name  = "localstack"
  networks_advanced {
    name = docker_network.dev-net.name
  }
  ports {
    internal = 4566
    external = 4566
  }
  env = [
    "LOCALSTACK_AUTH_TOKEN=${var.localstack_auth_token}",
    "DEBUG=${var.debug}",
    // "PERSISTENCE=1"
  ]
  /*volumes {
    container_path = "var/lib/localstack"
    host_path      = "/mount/localstack/volume"
  } */
  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
  }
  dynamic "ports" {
    for_each = range(4510, 4560)
    content {
      internal = ports.value
      external = ports.value
    }
  }
}

# Registry
resource "docker_image" "registry" {
  name         = "registry:2"
  keep_locally = true
}

resource "docker_container" "registry" {
  image   = docker_image.registry.image_id
  name    = "registry"
  restart = "always"
  networks_advanced {
    name = docker_network.dev-net.name
  }
  ports {
    internal = 5000
    external = 5000
  }

  provisioner "local-exec" {
    command = <<EOT
    echo "Waiting starts registry"
    until curl -s http://localhost:5000/ > /dev/null; do 
        sleep 0.5
      done
    
    docker tag ${var.image_name} ${var.local_registry}/${var.image_name}
    docker push ${var.local_registry}/${var.image_name}
    EOT
  }
}

# Helm relese for ingress-nginx
resource "helm_release" "ingress-nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  version = "4.15.1"
  wait    = true

  set = [
    {
      name  = "controller.service.ports.http"
      value = "8080"
    },
    {
      name  = "controller.service.ports.https"
      value = "8443"
    }
  ]
  depends_on = [
    docker_container.k3s
  ]
}

# Helm release for my app
resource "helm_release" "my-app" {
  name             = "my-app"
  repository       = null
  chart            = "${path.module}/../../kubernetes/helm/my-app"
  namespace        = "my-app"
  create_namespace = true

  depends_on = [
    docker_container.k3s,
    helm_release.ingress-nginx
  ]
}
