# Portfolio K3s bootstrap

This directory records the K3s configuration installed on the dedicated portfolio host. The installation checkpoint below precedes the first cluster start; it does not claim that Kubernetes is serving production.

## Scope

Operations are restricted to the portfolio repository and its dedicated Terraform-managed environment. Verify the portfolio instance identity before changing the host. Resolve instance and VPC identifiers from the verified portfolio state rather than publishing them here.

This bootstrap uses the existing ARM64 t4g.small instance and root disk. It does not require additional AWS resources or changes to public inbound rules.

## Recorded installation checkpoint — 2026-10-18

| Check | Observed result |
| --- | --- |
| EC2 status checks | System and instance: ok |
| Systems Manager | Online |
| K3s version | v1.36.5+k3s1 |
| K3s service | inactive; disabled at boot |
| SELinux | Permissive; mode was not changed |
| SELinux policy package installed | k3s-selinux-1.6-1.el8.noarch |
| Host services | Docker, NGINX and amazon-ssm-agent active |
| Docker production endpoint | Local HTTP check: 200 |
| Host NGINX/TLS | Local HTTPS check with hostname and certificate verification: 200 |

These endpoint checks validate the local serving path. An external DNS/HTTPS check remains a separate validation.

Before installation, the host reported 1.5 GiB available RAM and 5.5G available disk space on an 8.0G root filesystem. These are baseline observations, not post-start capacity measurements.

The observed host and Docker routes did not overlap the configured Kubernetes pod and service ranges.

## Configuration and runtime

`config.yaml` mirrors `/etc/rancher/k3s/config.yaml` on the host. `VERSION` records the exact installed release, resolved once from the official stable channel and passed to the installer with `INSTALL_K3S_VERSION`.

- Embedded containerd runs Kubernetes workloads; the current Docker container continues to serve production.
- Traefik and ServiceLB are disabled because host NGINX owns ports 80/443.
- The local-storage provisioner is disabled for the initial stateless workload.
- CoreDNS and Metrics Server remain enabled.
- Secret encryption at rest is enabled.
- The administrative kubeconfig uses mode `0600`.
- Kubernetes uses its default single-server SQLite datastore; no external database is provisioned.

The installer was run with `INSTALL_K3S_SKIP_START=true`, `INSTALL_K3S_SKIP_ENABLE=true`, and `INSTALL_K3S_SYMLINK=skip`. This staged the binary and systemd unit without starting the cluster or replacing existing command aliases.

Do not commit the generated kubeconfig, node tokens, database, Terraform state, plans, or credentials. This directory contains configuration and operational documentation only.

## First-start acceptance

After confirming the instance identity and reviewing the host configuration:

1. Start only the `k3s` systemd service.
2. Use `sudo /usr/local/bin/k3s kubectl` with the explicit kubeconfig `/etc/rancher/k3s/k3s.yaml` and the local API server.
3. Verify API readiness, node `jumito-portfolio` Ready, and the CoreDNS and Metrics Server deployments available.
4. Recheck the existing Docker endpoint and host NGINX/TLS, validating the real hostname and certificate.
5. Measure free memory, root disk space, and pod resource use.
6. Enable K3s at boot only after the acceptance checks succeed.

Starting Kubernetes changes host networking rules. Avoid broad firewall resets or automatic cleanup commands during diagnosis; preserve the live Docker serving path.

## Migration sequence

First validate a candidate Deployment and Service, then a Helm release. Change the NGINX upstream only after the candidate passes health checks. Keep the Docker production container available through validation and cutover.

The existing GitHub Actions pipeline still deploys Docker through OIDC and SSM. Kubernetes CI/CD integration and any registry decision remain pending. The local `k8s/` files have not yet been reviewed or uploaded through this synchronization.

## Sources

- [K3s configuration](https://docs.k3s.io/installation/configuration)
- [K3s server options](https://docs.k3s.io/cli/server)
- [K3s networking services](https://docs.k3s.io/networking/networking-services)
- [K3s datastore](https://docs.k3s.io/datastore)
- [Official installer](https://get.k3s.io)
