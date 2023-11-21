clean:
	rm -f terraform.tfstate* .terraform.lock.hcl

remove:
	terraform state rm helm_release.cert_manager || true
	terraform state rm helm_release.rancher_server || true
	terraform state rm rancher2_bootstrap.admin || true
	terraform state rm rancher2_cluster_v2.workload_node || true
	terraform state rm rancher2_app_v2.cis_benchmark_workload || true
	terraform state rm rancher2_app_v2.cis_benchmark_bug_cluster || true
	terraform state rm rancher2_cluster.bug_cluster || true
	terraform state rm rancher2_cluster_sync.bug_sync || true
	terraform state rm rancher2_cluster_sync.workload_sync || true

kill:
	$(MAKE) remove
	terraform destroy --auto-approve
	$(MAKE) clean

reboot:
	$(MAKE) remove
	terraform destroy --auto-approve
	$(MAKE) clean
	terraform init -reconfigure
	terraform apply --auto-approve


debug-rancher:
	k9s --kubeconfig ./kubeconfigs/kube_config_server.yaml

debug-workload:
	k9s --kubeconfig ./kubeconfigs/kube_config_workload.yaml

debug-bug:
	k9s --kubeconfig ./kubeconfigs/kube_config_bug.yaml

taint-bug:
	terraform taint aws_instance.bug_node || true
	terraform taint rancher2_cluster.bug_cluster || true
	terraform taint local_file.kube_config_bug_yaml || true
	terraform taint null_resource.bug_node_cmd || true
	terraform taint rancher2_cluster_sync.bug_sync || true
	terraform taint rancher2_app_v2.cis_benchmark_bug_cluster || true

destroy-bug:
	terraform destroy -target=rancher2_cluster.bug_cluster --auto-approve || true
	terraform destroy -target=local_file.kube_config_bug_yaml --auto-approve || true
	terraform destroy -target=null_resource.bug_node_cmd --auto-approve || true
	terraform destroy -target=rancher2_cluster_sync.bug_sync --auto-approve || true
	terraform destroy -target=rancher2_app_v2.cis_benchmark_bug_cluster --auto-approve || true
