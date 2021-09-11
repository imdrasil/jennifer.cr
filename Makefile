# === Sam shortcut
# next lines are autogenerated and any changes will be discarded after regenerating
CRYSTAL_BIN ?= `which crystal`
SAM_PATH ?= scripts/run.cr
.PHONY: sam
sam:
	$(CRYSTAL_BIN) run $(SAM_PATH) -- $(filter-out $@,$(MAKECMDGOALS))
%:
	@:
# === Sam shortcut

db-reset:
	make sam db:drop @ db:setup

format:
	crystal tool format --check -e"./scripts"
