# Create custom managed cluster for quickstart
resource "rancher2_cluster_v2" "workload_node" {
  provider = rancher2.WORKLOAD

  depends_on = [ helm_release.rancher_server]

  name               = "${var.prefix}-workload"
  kubernetes_version = var.workload_kubernetes_version
}
# kubeconfig for debugging
resource "local_file" "kube_config_workload_yaml" {
  depends_on = [ rancher2_cluster_v2.workload_node ]
  filename = format("%s/%s/%s", path.root, "kubeconfigs", "kube_config_workload.yaml")
  content  = rancher2_cluster_v2.workload_node.kube_config
}

resource "rancher2_cluster_sync" "workload_sync" {
  provider = rancher2.WORKLOAD
  depends_on = [ rancher2_cluster_v2.workload_node ]
  cluster_id =  rancher2_cluster_v2.workload_node.cluster_v1_id
}

resource "rancher2_app_v2" "cis_benchmark_workload" {
  provider = rancher2.WORKLOAD

  depends_on = [
    aws_instance.workload_node,
    rancher2_cluster_v2.workload_node
  ]

  cluster_id = rancher2_cluster_sync.workload_sync.cluster_id
  name = "rancher-cis-benchmark"
  namespace = "cis-operator-system"
  repo_name = "rancher-charts"
  chart_name = "rancher-cis-benchmark"
  #chart_version = "4.2.0"
  cleanup_on_fail = true
}