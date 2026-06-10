# Common — Shared Helm Charts

Shared Helm chart definitions that can be applied to any cluster provisioned by this repo (`single-k8s` or `multi-k8s`).

Charts are installed via **RKE2's built-in HelmChart CRD** — no standalone Helm CLI is required. RKE2 watches `/var/lib/rancher/rke2/server/manifests/` on every server node and automatically installs or reconciles any `HelmChart` resource placed there.

---

## Charts included

| Chart | Version | Namespace | Purpose |
|---|---|---|---|
| [cert-manager](https://cert-manager.io) | v1.16.2 | `cert-manager` | Automated TLS certificates (Let's Encrypt, self-signed, etc.) |
| [ingress-nginx](https://kubernetes.github.io/ingress-nginx) | 4.11.3 | `ingress-nginx` | HTTP/HTTPS Ingress controller, set as cluster default |

---

## Directory structure

```
common/
├── helm-charts/
│   ├── cert-manager.yaml    # HelmChart CR for cert-manager
│   └── ingress-nginx.yaml   # HelmChart CR for ingress-nginx
└── ansible/
    └── deploy-helm-charts.yml  # Playbook — copies CRs to master manifests dir
```

---

## How it works

RKE2 ships with a `helm-controller` that watches the manifests directory on every server node. When a `HelmChart` YAML is placed there, the controller:

1. Reads the `repo`, `chart`, and `version` fields
2. Pulls the chart and runs the equivalent of `helm install` / `helm upgrade`
3. Stores the release in the cluster's etcd

Upgrading or downgrading is just a file edit — change `version` in the YAML and re-run the playbook.

---

## Deploying

Run the playbook **from the target cluster's `ansible/` directory** so its `ansible.cfg` and `inventory/hosts.ini` are picked up automatically.

### single-k8s

```bash
cd single-k8s/ansible
ansible-playbook ../../common/ansible/deploy-helm-charts.yml
```

### multi-k8s

```bash
cd multi-k8s/ansible
ansible-playbook ../../common/ansible/deploy-helm-charts.yml
```

> For multi-k8s this installs ingress-nginx and cert-manager on **all 3 clusters** — one per master. Run with `--limit master-1` (or `cluster1_master`) to target a single cluster only.

---

## Verifying installation

After the playbook finishes, the helm-controller takes a minute or two to pull and install the charts. Check status with:

```bash
# Watch HelmChart reconciliation status
kubectl get helmchart -n kube-system

# cert-manager pods
kubectl get pods -n cert-manager

# ingress-nginx pods
kubectl get pods -n ingress-nginx

# ingress-nginx LoadBalancer — get the external AWS NLB hostname
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

Expected output:

```
NAME            READY   STATUS    RESTARTS   AGE
cert-manager    3/3     Running   0          2m
ingress-nginx   2/2     Running   0          2m
```

---

## Upgrading / downgrading a chart

1. Edit the `version` field in `common/helm-charts/<chart>.yaml`
2. Re-run the playbook — Ansible copies the updated file and RKE2 reconciles automatically

```bash
# Example: upgrade ingress-nginx to 4.12.0
# Edit common/helm-charts/ingress-nginx.yaml → version: "4.12.0"

cd single-k8s/ansible
ansible-playbook ../../common/ansible/deploy-helm-charts.yml
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

Once cert-manager is running, create a `ClusterIssuer` to issue certificates automatically. Apply this to your cluster after installation:

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
            ingressClassName: nginx
```

```bash
kubectl apply -f letsencrypt-issuer.yaml
```

Then reference it in any Ingress:

```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-prod
```
