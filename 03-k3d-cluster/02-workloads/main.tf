terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

provider "kubernetes" {
  config_path = "${path.module}/../kubeconfig.yaml"
}

resource "kubernetes_namespace" "practice" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.practice.metadata[0].name
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = { app = "nginx" }
    }

    template {
      metadata {
        labels = { app = "nginx" }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:alpine"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.practice.metadata[0].name
  }

  spec {
    selector = { app = "nginx" }
    type     = "NodePort"

    port {
      port        = 80
      target_port = 80
      node_port   = var.node_port
    }
  }
}
