.PHONY: helm-docs
helm-docs:
ifeq (, $(shell which helm-docs))	
	$(info "helm-docs not found, installing")
	$(shell go install github.com/norwoodj/helm-docs/cmd/helm-docs@latest)
endif
	helm-docs