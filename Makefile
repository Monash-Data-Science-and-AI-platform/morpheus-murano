TARGET=edu.monash.merc.Morpheus
IMAGE=MERC Morpheus (Ubuntu 20.04 LTS Focal)
.PHONY: $(TARGET).zip

all: $(TARGET).zip

build: $(TARGET).zip

clean:
	rm -rf $(TARGET).zip

upload: $(TARGET).zip
	murano package-import -c "Big Data" --package-version 1.0 --exists-action u $(TARGET).zip

update-image-id:
	@echo "Searching for latest image of $(IMAGE)..."
	@image_id=$$(openstack image show -f value -c id "$(IMAGE)"); \
	if [ -z "$$image_id" ]; then \
		echo "Image ID not found"; exit 1; \
	fi; \
	echo "Found ID: $$image_id"; \
    sed -i "s/image:.*/image: $$image_id/g" $(TARGET)/UI/ui.yaml

$(TARGET).zip:
	rm -f $@; cd $(TARGET); zip ../$@ -r *; cd ..
