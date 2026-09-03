# terraform-k3s-local-prod-env
This project represents local Devops-stand closer to real production-environment.
__It includes:__
  - ✅ Kubernetes-cluster (k3s) in Docker containers;
  - ✅ Infrastructure as Code (Terraform);
  - ✅ CI/CD (Gitea Action);
  - ✅ Docker Registry (registry);
  - ~ Monitoring (Prometheus + Grafana) in the process;
  - ~ Logs (Loki + Promtail) in the process;
  - ✅ GitOps (Helm);

 __System requirements:__
   - RAM: 8+ Gb;
   - CPU: 2+ Core;
   - Disc: 20+ Gb (recommended SSD);
   - Required software:
       - Terraform (v1.16.0+);
       - Docker (v29.7.2+);
       - Kubectl (v1.36.3+);
       - Helm (v4.2.4+).

__CI/CD Pipeline__
The pipeline automatically starts when a push to main.
Whats happend:
  1. Build Docker-image appllications;
  2. Image push to local registry;
  3. Deploy application with hepls Helm;
  4. Starts acess check.

__Frequent problems:__
see. TROUBLESHOOTING.md

__Plans for improvement:__
  - Add ArgoCD for real GitOps;
  - Implement Vault for secure using credentials;
  - Set up automatic scaling (HPA);
  - Add backup etcd (optional).
