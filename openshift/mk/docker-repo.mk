.PHONY: tag push

tag: ## Tag LOCAL_IMAGE as belonging to the remote registry.
	docker tag $(LOCAL_IMAGE) $(REMOTE_IMAGE)

push: ## Push the remote image. Accepts NAME and VERSION.
	docker push $(REMOTE_IMAGE)
