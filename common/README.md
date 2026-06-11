# Common — Shared Helm Charts

Shared Helm chart definitions that can be applied to any cluster provisioned by this repo (`single-k8s` or `multi-k8s`).

Charts are installed via **RKE2's built-in HelmChart CRD** — no standalone Helm CLI is required. RKE2 watches `/var/lib/rancher/rke2/server/manifests/` on every server node and automatically installs or reconciles any `HelmChart` resource placed there.

---

## Charts included

| Chart | Version | Namespace | Purpose |
|---|---|---|---|
| [cert-manager](https://cert-manager.io) | v1.16.2 | `cert-manager` | Automated TLS certificates (Let's Encrypt, self-signed, etc.) |
| [ingress-nginx](https://kubernetes.github.io/ingress-nginx) | 4.11.3 | `ingress-nginx` | HTTP/HTTPS Ingress controller (option A), set as cluster default |
| [traefik](https://doc.traefik.io/traefik/) | 35.2.0 | `traefik` | HTTP/HTTPS Ingress controller (option B), set as cluster default |
| [keycloakx](https://github.com/codecentric/helm-charts/tree/master/charts/keycloakx) | 7.2.0 (Keycloak 26.x) | `keycloak` | Identity and access management |
| [external-dns](https://kubernetes-sigs.github.io/external-dns/) | 1.21.1 | `external-dns` | Auto-creates Route 53 records for Ingress hosts |

You install **one ingress controller per cluster** — nginx *or* traefik — by choosing the matching playbook. cert-manager is deployed by both playbooks.

> RKE2's bundled `rke2-ingress-nginx` is disabled in the server config (`disable: rke2-ingress-nginx`) so it doesn't conflict with the controller installed here.

---

## Directory structure

```
common/
├── helm-charts/
│   ├── cert-manager.yaml    # HelmChart CR for cert-manager
│   ├── ingress-nginx.yaml   # HelmChart CR for ingress-nginx
│   └── traefik.yaml         # HelmChart CR for traefik
└── ansible/
    ├── deploy-helm-charts-nginx.yml    # cert-manager + ingress-nginx
    ├── deploy-helm-charts-traefik.yml  # cert-manager + traefik
    ├── deploy-keycloak.yml             # keycloak + external-dns (Route 53)
    └── templates/
        ├── external-dns.yaml.j2        # HelmChart CR (templated with your domain)
        ├── keycloak.yaml.j2            # HelmChart CR (templated with your domain)
        └── letsencrypt-issuer.yaml.j2  # ClusterIssuer (optional TLS)
```

---

## How it works

RKE2 ships with a `helm-controller` that watches the manifests directory on every server node. When a `HelmChart` YAML is placed there, the controller:

1. Reads the `repo`, `chart`, and `version` fields
2. Pulls the chart and runs the equivalent of `helm install` / `helm upgrade`
3. Stores the release in the cluster's etcd

Upgrading or downgrading is just a file edit — change `version` in the YAML and re-run the playbook.

Each playbook also removes the *other* controller's manifest file from the manifests directory, so only one ingress controller is reconciled at a time.

---

## Deploying

Run the playbook **from the target cluster's `ansible/` directory** so its `ansible.cfg` and `inventory/hosts.ini` are picked up automatically. Pick the playbook for the ingress controller you want:

### single-k8s

```bash
cd single-k8s/ansible

# with ingress-nginx
ansible-playbook ../../common/ansible/deploy-helm-charts-nginx.yml

# or with traefik
ansible-playbook ../../common/ansible/deploy-helm-charts-traefik.yml
```

### multi-k8s

```bash
cd multi-k8s/ansible

# with ingress-nginx
ansible-playbook ../../common/ansible/deploy-helm-charts-nginx.yml

# or with traefik
ansible-playbook ../../common/ansible/deploy-helm-charts-traefik.yml
```

> For multi-k8s this installs the charts on **all 3 clusters** — one per master. Run with `--limit master-1` (or `cluster1_master`) to target a single cluster only.

---

## Switching ingress controllers on a running cluster

Removing a manifest file stops RKE2 from re-creating the chart, but it does **not** uninstall it. To switch, first delete the old HelmChart resource, then run the other playbook:

```bash
# nginx -> traefik
kubectl delete helmchart -n kube-system ingress-nginx
cd single-k8s/ansible && ansible-playbook ../../common/ansible/deploy-helm-charts-traefik.yml

# traefik -> nginx
kubectl delete helmchart -n kube-system traefik
cd single-k8s/ansible && ansible-playbook ../../common/ansible/deploy-helm-charts-nginx.yml
```

Notes when switching:

- Deleting the old controller tears down its AWS NLB — the new controller gets a **different** LB hostname, so update any DNS records. Expect a short window of downtime.
- Update `spec.ingressClassName` in your Ingress resources (`nginx` ↔ `traefik`), or omit it since both charts register themselves as the default class.
- `nginx.ingress.kubernetes.io/*` annotations have no effect on Traefik (and vice versa). Traefik equivalents are `traefik.ingress.kubernetes.io/*` annotations or `Middleware` CRDs.

---

## Keycloak + automatic Route 53 DNS

`deploy-keycloak.yml` installs **Keycloak** (codecentric `keycloakx` chart, official Keycloak image) and **external-dns**. external-dns watches Ingress resources and automatically creates a Route 53 record (e.g. `keycloak.endpoint.com`) pointing at the LoadBalancer of whichever ingress controller is installed — traefik or nginx.

### Prerequisites

1. An ingress controller + cert-manager already deployed (see above)
2. A **Route 53 public hosted zone** for your domain in the same AWS account
3. Nodes provisioned with the Route 53 IAM role — included in the Terraform `modules/ec2` (re-run `terraform apply` on clusters created before this was added; the instance-profile attachment and IMDS hop-limit change apply in place)

### Deploy

Keycloak runs in production mode (`start`) with an external PostgreSQL database — RDS is the natural choice on AWS.

```bash
cd single-k8s/ansible   # or multi-k8s/ansible (use --limit, see note below)

ansible-playbook ../../common/ansible/deploy-keycloak.yml \
  -e base_domain=endpoint.com \
  -e keycloak_admin_password='KcAdmin!' \
  -e db_host=my-postgres.rds.amazonaws.com \
  -e db_name=keycloak \
  -e db_username=keycloak \
  -e db_password='DbPass!' \
  -e letsencrypt_email=you@example.com        # optional — enables HTTPS
```

| Variable | Default | Purpose |
|---|---|---|
| `base_domain` | — (required) | Route 53 hosted zone, e.g. `endpoint.com` |
| `keycloak_admin_password` | — (required) | Initial Keycloak admin password |
| `db_host` | — (required) | PostgreSQL hostname, e.g. an RDS endpoint |
| `db_name` | — (required) | Database name |
| `db_username` | — (required) | Database user |
| `db_password` | — (required) | Database password |
| `keycloak_host` | `keycloak.<base_domain>` | Ingress hostname |
| `keycloak_admin_user` | `admin` | Initial Keycloak admin user |
| `keycloak_replicas` | `2` | Number of Keycloak pods |
| `db_port` | `5432` | PostgreSQL port |
| `ingress_class` | `traefik` | `traefik` or `nginx` — must match the installed controller |
| `letsencrypt_email` | unset | If set, creates a `letsencrypt-prod` ClusterIssuer and enables TLS |
| `aws_region` | `us-east-1` | Region for the external-dns AWS client |
| `external_dns_txt_owner` | inventory hostname | Ownership ID — keep unique per cluster sharing a zone |

> **multi-k8s:** run with `--limit master-1` (or `cluster1_master`). Deploying to all 3 clusters would have them fight over the same `keycloak.<domain>` record unless each cluster gets a distinct `keycloak_host`.

### Verify

```bash
kubectl get pods -n external-dns
kubectl logs -n external-dns deploy/external-dns | tail   # look for "CREATE keycloak.<domain>"
kubectl get pods -n keycloak
kubectl get ingress -n keycloak                            # ADDRESS = controller's NLB hostname
```

Once the record propagates, open `https://keycloak.<base_domain>` and log in with the admin credentials.

> **Note:** Keycloak runs in production mode (`start`) backed by PostgreSQL. Data persists across pod restarts. The `--optimized` flag skips the Keycloak build step at startup — if you add providers or change themes, rebuild the image or remove that flag first.

---

## Verifying installation

After the playbook finishes, the helm-controller takes a minute or two to pull and install the charts. Check status with:

```bash
# Watch HelmChart reconciliation status
kubectl get helmchart -n kube-system

# cert-manager pods
kubectl get pods -n cert-manager

# ingress controller pods (pick the one you installed)
kubectl get pods -n ingress-nginx
kubectl get pods -n traefik

# LoadBalancer — get the external AWS NLB hostname
kubectl get svc -n ingress-nginx ingress-nginx-controller
kubectl get svc -n traefik traefik
```

---

## Upgrading / downgrading a chart

1. Edit the `version` field in `common/helm-charts/<chart>.yaml`
2. Re-run the playbook — Ansible copies the updated file and RKE2 reconciles automatically

```bash
# Example: upgrade ingress-nginx to 4.12.0
# Edit common/helm-charts/ingress-nginx.yaml → version: "4.12.0"

cd single-k8s/ansible
ansible-playbook ../../common/ansible/deploy-helm-charts-nginx.yml
```

No `helm upgrade` command needed.

---

## Customising chart values

All Helm values go in the `valuesContent` block of each `HelmChart` YAML. This is equivalent to a `values.yaml` file passed to `helm install -f`.

### ingress-nginx: use NodePort instead of LoadBalancer (no ELB cost)

```yaml
# common/helm-charts/ingress-nginx.yaml
valuesContent: |-
  controller:
    replicaCount: 2
    service:
      type: NodePort
    ingressClassResource:
      default: true
```

### traefik: use NodePort instead of LoadBalancer (no ELB cost)

```yaml
# common/helm-charts/traefik.yaml
valuesContent: |-
  deployment:
    replicas: 2
  service:
    type: NodePort
  ingressClass:
    enabled: true
    isDefaultClass: true
```

### cert-manager: set resource limits

```yaml
# common/helm-charts/cert-manager.yaml
valuesContent: |-
  installCRDs: true
  replicaCount: 1
  resources:
    requests:
      cpu: 10m
      memory: 32Mi
    limits:
      cpu: 100m
      memory: 128Mi
```

---

## Creating a ClusterIssuer for Let's Encrypt

Once cert-manager is running, create a `ClusterIssuer` to issue certificates automatically. Apply this to your cluster after installation. Set `ingressClassName` to the controller you installed (`nginx` or `traefik`):

```yaml
# letsencrypt-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your@email.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            ingressClassName: nginx   # or traefik
```

```bash
kubectl apply -f letsencrypt-issuer.yaml
```

Then reference it in any Ingress:

```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-prod
```
