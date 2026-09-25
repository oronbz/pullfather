.PHONY: release

ifeq (release,$(firstword $(MAKECMDGOALS)))
VERSION ?= $(word 2,$(MAKECMDGOALS))
$(eval $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS)):;@:)
endif

release:
	@./scripts/release.sh $(VERSION)
