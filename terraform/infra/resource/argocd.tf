# =============================================================================================
# ArgoCD 설치
# - LoadBalancer(NLB) 로 외부 접속 (실습의 kubectl patch svc 대체)
# - HTTP 로 접속 (실습의 --insecure 패치 대체)
# - admin 비밀번호를 GitHub Secret 의 bcrypt 해시로 고정
# =============================================================================================
locals {
  argocd_base_values = {
    configs = {
      params = {
        "server.insecure" = true
      }
    }
    server = {
      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
          "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
        }
      }
    }
  }

  # 해시가 있을 때만 비밀번호 설정 (없으면 ArgoCD 가 임의 생성)
  argocd_password_values = var.argocd_admin_password_hash == "" ? {} : {
    configs = {
      secret = {
        argocdServerAdminPassword = var.argocd_admin_password_hash
      }
    }
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true
  timeout          = 600

  # 공개 설정과 비밀번호를 별도 values 로 전달 (뒤의 값이 병합됨)
  values = [
    yamlencode(local.argocd_base_values),
    yamlencode(local.argocd_password_values),
  ]

  # LB Controller 가 먼저 있어야 argocd-server Service 가 NLB 로 생성됨
  depends_on = [helm_release.lbc]
}

# ArgoCD Application 등록 (Git 의 k8s/ 폴더를 company 네임스페이스에 동기화)
resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version
  namespace  = "argocd"

  values = [yamlencode({
    applications = {
      company = {
        namespace  = "argocd"
        project    = "default"
        finalizers = ["resources-finalizer.argocd.argoproj.io"] # 앱 삭제 시 리소스(ALB 포함) 정리
        source = {
          repoURL        = var.git_repo_url
          targetRevision = var.git_revision
          path           = "k8s"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "company"
        }
        syncPolicy = {
          automated   = { prune = true, selfHeal = true }
          syncOptions = ["CreateNamespace=true"]
          # 컨트롤러 웹훅 준비 전 Ingress 생성 실패 대비 재시도
          retry = {
            limit   = 10
            backoff = { duration = "30s", factor = 2, maxDuration = "5m" }
          }
        }
      }
    }
  })]

  depends_on = [helm_release.argocd]
}
