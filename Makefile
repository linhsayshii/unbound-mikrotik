IMAGE ?= unbound-mikrotik
TAG ?= latest
PLATFORM ?= linux/arm64
ARCHIVE ?= $(IMAGE)-$(subst /,-,$(PLATFORM)).tar

.PHONY: build archive save check run

build:
	docker buildx build --platform $(PLATFORM) --load -t $(IMAGE):$(TAG) .

archive:
	docker buildx build --platform $(PLATFORM) --load -t $(IMAGE):$(TAG) .
	docker save $(IMAGE):$(TAG) -o $(ARCHIVE)

save:
	docker save $(IMAGE):$(TAG) -o $(ARCHIVE)

check:
	docker run --rm --entrypoint unbound-checkconf $(IMAGE):$(TAG) /etc/unbound/unbound.conf

run:
	docker run --rm -p 5353:53/udp -p 5353:53/tcp $(IMAGE):$(TAG)
