# Terraform state and CI/CD pipeline compromise lab.
# Anyone who clones this repo needs only docker + make; everything runs
# against LocalStack in Docker.
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

SCENARIO ?= vulnerable

.PHONY: help
help: ## list available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "};{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: up
up: ## start LocalStack + attacker webhook, wait until healthy
	docker compose up -d --wait
	./scripts/check/stack-up.sh

.PHONY: down
down: ## stop the demo runtime
	docker compose down --remove-orphans

.PHONY: reset
reset: ## full wipe: containers + emulator volume + captured webhook logs + state
	docker compose down -v --remove-orphans
	rm -rf .run/webhook
	@echo "reset: clean slate"

.PHONY: verify
verify: ## run all local sanity gates (must pass before any commit)
	./scripts/check/stack-up.sh
	./scripts/check/stack-applied.sh
	./scripts/check/aws-portability.sh
	./scripts/check/ports-and-secrets.sh

.PHONY: selftest
selftest: ## prove the gates have teeth: plant violations, watch each fail, clean up
	scripts/dev/selftest-gates.sh

.PHONY: attack
attack: up ## run the attack chain (acts 1-3) against the vulnerable scenario
	./attack/act1/run.sh
	@echo
	@echo "act 2: the rogue module phones home on the next pipeline run"
	$(MAKE) --no-print-directory apply >/dev/null
	./attack/act2/run.sh
	@echo
	@echo "act 3: lateral movement from the pipeline identity into prod"
	./attack/act3/run.sh

.PHONY: bootstrap
bootstrap: up ## create the $(SCENARIO) state backend (bucket + lock table)
	source scripts/env/localstack.env && \
	tofu -chdir=scenarios/$(SCENARIO)/bootstrap init -input=false \
		-var-file=../localstack.tfvars && \
	tofu -chdir=scenarios/$(SCENARIO)/bootstrap apply -auto-approve -input=false \
		-var-file=../localstack.tfvars

.PHONY: apply
apply: ## apply the $(SCENARIO) scenario against LocalStack
	source scripts/env/localstack.env && \
	tofu -chdir=scenarios/$(SCENARIO) init -reconfigure -input=false \
		-backend-config=$(CURDIR)/backend-config/localstack.hcl && \
	tofu -chdir=scenarios/$(SCENARIO) apply -auto-approve -input=false \
		-var-file=localstack.tfvars

.PHONY: destroy
destroy: ## destroy the $(SCENARIO) scenario
	source scripts/env/localstack.env && \
	tofu -chdir=scenarios/$(SCENARIO) destroy -auto-approve -input=false \
		-var-file=localstack.tfvars || true