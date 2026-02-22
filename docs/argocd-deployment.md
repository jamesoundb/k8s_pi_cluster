# ArgoCD Deployment Quick Reference

## Deployment Sequence

After your cluster is fully operational (k8s-post-config.yml complete):

```bash
# 1. Deploy ArgoCD to control plane
ansible-playbook -i inventory.yml k8s-argocd-deploy.yml
```

## Immediate Post-Deployment Steps

```bash
# 2. Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# 3. Access web UI (in a separate terminal)
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Then: https://localhost:8080

# 4. Create trading namespace and secrets
kubectl create namespace trading

kubectl create secret generic trading-credentials \
  --from-literal=SCHWAB_CLIENT_ID="your-client-id" \
  --from-literal=SCHWAB_CLIENT_SECRET="your-client-secret" \
  --from-literal=SCHWAB_MCP_DISCORD_TOKEN="your-bot-token" \
  --from-literal=SCHWAB_MCP_DISCORD_CHANNEL_ID="1467642760105431196" \
  --from-literal=SCHWAB_MCP_DISCORD_APPROVERS="725433829288050698" \
  --from-literal=DISCORD_WEBHOOK_URL="your-webhook-url" \
  --from-literal=DRY_RUN="true" \
  -n trading

# 5. Create ArgoCD Application from trading-agent-gitops repo
# First, edit ~/trading-agent-gitops/argocd-app.yaml and update USERNAME
sed -i 's|USERNAME|your-github-username|g' ~/trading-agent-gitops/argocd-app.yaml

# Then apply it
kubectl apply -f ~/trading-agent-gitops/argocd-app.yaml

# 6. Monitor deployment
kubectl get applications -n argocd -w
kubectl logs -f -n trading deployment/trading-agent
```

## Verification Checklist

```bash
# ArgoCD running?
kubectl get pods -n argocd

# Trading Application synced?
kubectl get applications -n argocd

# Trading agent pods running?
kubectl get pods -n trading

# Trading credentials in place?
kubectl get secret -n trading trading-credentials
```

## Common Commands

```bash
# View ArgoCD applications
kubectl get applications -n argocd -o wide

# Get application details
kubectl describe application trading-agent -n argocd

# Manual sync (if needed)
argocd app sync trading-agent --force

# View application logs
kubectl logs -f -n argocd deployment/argocd-server
kubectl logs -f -n argocd deployment/argocd-repo-server

# Check trading agent logs
kubectl logs -f -n trading deployment/trading-agent -c trading-agent

# Access trading journal
kubectl exec -it -n trading $(kubectl get pod -n trading -l app=trading-agent -o jsonpath='{.items[0].metadata.name}') -- tail -20 /app/journal/trading_journal.csv
```

## File Locations

- **Playbook**: `/home/james/k8s_stuff/k8s_pi_cluster/k8s-argocd-deploy.yml`
- **Role**: `/home/james/k8s_stuff/k8s_pi_cluster/roles/argocd/`
- **GitOps Repo**: `/home/james/trading-agent-gitops/`
- **ArgoCD App Manifest**: `/home/james/trading-agent-gitops/argocd-app.yaml`

## Help Commands

```bash
# Reset ArgoCD (full reinstall)
kubectl delete namespace argocd
ansible-playbook -i inventory.yml k8s-argocd-deploy.yml

# Check what ArgoCD will deploy
kubectl get applications -n argocd trading-agent -o yaml

# Stream all ArgoCD component logs
kubectl logs -f -n argocd -l app.kubernetes.io/part-of=argocd --all-containers=true --timestamps=true
```

## Next: Switch from DRY-RUN to LIVE

Only after 4+ weeks of successful dry-run validation:

```bash
# Delete old secret
kubectl delete secret -n trading trading-credentials

# Create new secret with DRY_RUN=false
kubectl create secret generic trading-credentials \
  --from-literal=SCHWAB_CLIENT_ID="your-client-id" \
  --from-literal=SCHWAB_CLIENT_SECRET="your-client-secret" \
  --from-literal=SCHWAB_MCP_DISCORD_TOKEN="your-bot-token" \
  --from-literal=SCHWAB_MCP_DISCORD_CHANNEL_ID="1467642760105431196" \
  --from-literal=SCHWAB_MCP_DISCORD_APPROVERS="725433829288050698" \
  --from-literal=DISCORD_WEBHOOK_URL="your-webhook-url" \
  --from-literal=DRY_RUN="false" \
  -n trading

# Restart pods to pick up new secret
kubectl rollout restart deployment/trading-agent -n trading
kubectl rollout restart deployment/schwab-mcp-server -n trading

# Monitor closely
kubectl logs -f -n trading deployment/trading-agent
```
