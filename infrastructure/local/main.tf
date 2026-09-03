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

# Create custom docker network
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
  env = [
    "GITEA__actions__ENABLED=true",                                          # Use this for registry runner
    "GITEA_RUNNER_REGISTRATION_TOKEN=${var.gitea_runner_registration_token}" # Automatically registers the runner
  ]
  volumes {
    container_path = "/data"
    host_path      = "/mount/gitea/data"
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

# Runner for Gitea
resource "docker_image" "runner" {
  name         = "gitea/runner"
  keep_locally = true
}

resource "docker_container" "runner" {
  image   = docker_image.runner.image_id
  name    = "runner"
  restart = "always" # Optional setting
  networks_advanced {
    name = docker_network.dev-net.name
  }
  env = [
    "CONFIG_FILE=/config.yaml", # Use this for connection the runner to custom docker network
    "GITEA_INSTANCE_URL=${var.gitea_instance_url}",
    "GITEA_RUNNER_REGISTRATION_TOKEN=${var.gitea_runner_registration_token}",
    "GITEA_RUNNER_NAME=runner-a"
  ]
  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
  }
  volumes {
    host_path      = abspath("${path.module}/../../gitea/runner-a/config.yaml")
    container_path = "/config.yaml"
  }
  volumes {
    host_path      = abspath("${path.module}/../../gitea/runner-a/data")
    container_path = "/data"
  }
  volumes {
    host_path      = abspath("${path.module}/../../gitea/runner-a/cache")
    container_path = "/root/.cache"
  }
  ports {
    internal = 8088
    external = 8088
  }

  depends_on = [
    docker_container.gitea
  ]

  provisioner "local-exec" {
    command = "sleep 10" # Waiting for finally creation Gitea
  }
}

# Config file for registries k3s
resource "local_file" "k3s_registries" {
  filename = "${path.module}/registries.yaml" # Use this for access to local registry
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
  command    = ["server", "--tls-san=k3s"] # Runner using TLS-SAN for deploy application to cluster 
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

# Creating s3-bucket
resource "null_resource" "s3-terraform-state" {
  provisioner "local-exec" {
    command = "aws --endpoing-url http://localhost:4566 s3 mb s3://terraform-state"
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
    "PERSISTENCE=1" # Using for saving data between reboots
  ]
  volumes {
    container_path = "/var/lib/localstack"
    host_path      = "/mount/localstack/volume"
  }
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
  restart = "always" # Optional setting
  networks_advanced {
    name = docker_network.dev-net.name
  }
  ports {
    internal = 5000
    external = 5000
  }

  provisioner "local-exec" { # Using defaults tag - latest
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
    } # Using NodePort because to get enternal_ip in local network is almost impossible
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

/*resource "helm_release" "prometheus-stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "88.6.2"

  values = [
    yamlencode({
      alertmanager = {
        enabled = false
      }
      prometheus-node-exporter = {
        enabled = false
      }
      kube-state-metrics = {
        enabled = false
      }
      prometheus = {
        prometheusSpec = {
          scrapeInterval     = "60s"
          evaluationInterval = "60s"
          retention          = "24h"
          retentionSize      = "2GB"
          resources = {
            requests = {
              cpu    = "100m"
              memory = "512Mi"
            }
            limits = {
              memory = "1Gi"
            }
          }
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "local-path"
                acessModes       = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "2Gi"
                  }
                }
              }
            }
          }
        }
      }
      grafana = {
        enabled       = true
        adminPassword = "admin"
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            memory = "256Mi"
          }
        }
        persistence = {
          enabled = false
        }
        ingress = {
          enabled = false
        }
        additionalDataSources = [{
          name      = "Loki"
          type      = "loki"
          url       = "http://loki.monitoring.svc.cluster.local:3100"
          acess     = "proxy"
          isDefault = false
        }]
        dashboardProviders = {}
        dashboards         = {}
      }
      kubeProxy = { enabled = false }
    })
  ]

  depends_on = [docker_container.k3s]
}

resource "helm_release" "loki" {
  name             = "loki"
  repository       = "https://grafana-community.github.io/helm-charts"
  chart            = "loki"
  namespace        = "monitoring"
  create_namespace = true
  version          = "18.11.7"

  values = [
    yamlencode({
      deploymentMode = "Monolithic"
      loki = {
        auth_enabled = false
        commonConfig = {
          replication_factor = 1
        }
        storage = {
          type = "filesystem"
        }
        schemaConfig = {
          configs = [{
            from         = "2026-01-01"
            store        = "tsdb"
            object_store = "filesystem"
            schema       = "v13"
            index = {
              prefix = "loki_index_"
              period = "24h"
            }
          }]
        }
        limits_cinfig = {
          retention_period            = "48h"
          ingestion_rate_mb           = 4
          ingestion_burst_size_mb     = 6
          max_entries_limit_per_query = 5000
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            memory = "256Mi"
          }
        }
        compactor = {
          enabled = false
        }
        distributor = {
          enabled = false
        }
        ingester = {
          enabled = false
        }
        querier = {
          enabled = false
        }
        queryFrontend = {
          enabled = false
        }
        ruler = {
          enabled = false
        }
      }
      promtail = {
        enabled = true
        config = {
          clients = [{
            url = "http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push"
          }]
          resources = {
            requests = {
              cpu    = "50m"
              memory = "128Mi"
            }
            limits = {
              memory = "256Mi"
            }
          }
          scrapeConfigs = [{
            job_name = "kubernetes-pods"
            kubernetes_sd_configs = [{
              role = "pod"
            }]
            relabel_configs = [{
              source_labels = ["__meta_kubernetes_pod_annotation_kubernetes_io_log"]
              action        = "keep"
              regex         = "true"
            }]
          }]
        }
      }
    })
  ]

  depends_on = [docker_container.k3s]
} */
