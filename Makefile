SHELL=/bin/bash
DISTRO=bookworm
DNAME=reprepro
REPO=$(shell pwd)/repo/$(DISTRO)
PUBKEY=$(REPO)/phonebocx.gpg.key
WEBROOTPUBKEY=/var/www/html/phonebocx.gpg.key
SRCKEY=secret/phonebocx.signing.key
INCOMING=$(shell pwd)/incoming
ARCHIVE=$(shell pwd)/archive
DPARAMS=-e DISTRO=$(DISTRO) -v $(shell pwd):/depot -v $(INCOMING):/incoming -v $(REPO):/repo-$(DISTRO) -v $(ARCHIVE):/archive-$(DISTRO) --rm $(DNAME)

export DISTRO INCOMING

.PHONY: docker shell
docker: .dockerimg

.PHONY: shell
shell: .dockerimg
	docker run -it -w /depot $(DPARAMS) bash

.PHONY: repo
repo: $(WEBROOTPUBKEY) $(REPO)/conf/distributions $(REPO)/phonebocx.sources $(REPO)/conf/override | $(INCOMING) $(ARCHIVE)
	@DEBS=$(wildcard $(INCOMING)/*deb); if [ "$$DEBS" ]; then \
		echo "Processing '$$DEBS'"; \
		docker run -it -w /depot $(DPARAMS) ./import.sh; \
	else \
		echo "No debs to import"; \
	fi

.dockerimg: docker/repo-signing-key-fingerprint docker/repo-signing-key $(wildcard docker/*) | $(INCOMING) $(ARCHIVE)
	docker build -t $(DNAME) docker && touch .dockerimg

$(INCOMING) $(ARCHIVE):
	mkdir -p $@

docker/repo-signing-key: $(SRCKEY)
	@cp $< $@

docker/repo-signing-key-fingerprint: $(SRCKEY)
	@gpg --list-packets $< | awk '/hashed subpkt 33/ { print $$9; exit }' | tr -d ')' > $@

$(SRCKEY):
	@echo "Package signing key missing, can't continue" && exit 99

$(REPO)/conf/distributions: templates/distributions.template docker/repo-signing-key-fingerprint
	@mkdir -p $(@D)
	@sed -e 's/__SIGNINGKEY__/$(shell cat docker/repo-signing-key-fingerprint)/' -e 's/__DISTRO__/$(DISTRO)/' < templates/distributions.template > $@

$(REPO)/conf/override: override
	@cp $< $@

$(WEBROOTPUBKEY) $(PUBKEY): docker/repo-signing-key-fingerprint
	@gpg --export -a --export-options export-minimal $(shell cat $<) > $@

$(REPO)/phonebocx.sources: templates/phonebocx.sources.template $(PUBKEY)
	@sed -e 's/__DISTRO__/$(DISTRO)/' < templates/phonebocx.sources.template > $@
	

