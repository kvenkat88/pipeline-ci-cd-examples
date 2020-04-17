HISTCONTROL = ignorespace
REPOSITORY = hps-core-services
SERVER_IP = 10.82.102.129
SERVER_USERNAME = ec2-user
TAG := dev-08042020
STAGE = test
NEW_TAG := $(STAGE)-$(TAG)
CONTAINER_NAME := $(REPOSITORY)-$(STAGE)-$(TAG)
PORT = 5000
AWS_ACCESS_KEY_ID =
AWS_ACCOUNT_ID =
AWS_SECRET_ACCESS_KEY =
AWS_DEFAULT_REGION := us-east-1
AWS_ECR_LOGIN =
ECR_URI := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_DEFAULT_REGION).amazonaws.com

.PHONY: all

all: aws_ecr_login docker_tag_aws_ecr_put fetch_running_container_id_in_remote_machine stop_running_instance ssh_login_to_machine

aws_ecr_login:
	@$(eval AWS_ECR_LOGIN = $(shell aws ecr get-login --no-include-email --region $(AWS_DEFAULT_REGION)))

clean_docker_images_before_startup:
	@echo "TODO: Remove unused images in remote machine"

docker_tag_aws_ecr_put:
	
	@echo "Entering the IMAGE_DIGEST fetch step"
	
	@$(eval IMAGE_DIGEST = $(shell aws ecr describe-images --repository-name $(REPOSITORY) --region $(AWS_DEFAULT_REGION) --filter 'tagStatus=TAGGED' --image-ids imageTag=$(TAG) --query 'sort_by(imageDetails,& imagePushedAt)[0].imageDigest'))

	@echo "Entering the Manifest creation step"
	
	@$(eval MANIFEST = $(shell aws ecr batch-get-image --repository-name $(REPOSITORY) --region $(AWS_DEFAULT_REGION) --image-ids imageDigest=$(IMAGE_DIGEST) --query 'images[].imageManifest' --output text))
	
	echo $(MANIFEST)
	
	@echo "Entering the ECR put image fetch step"
		
	@$(eval OUTPUT_PUT_IMAGE = $(shell aws ecr put-image --repository-name $(REPOSITORY) --region $(AWS_DEFAULT_REGION) --image-tag $(NEW_TAG) --image-manifest "$(MANIFEST)"))
	
	echo $(OUTPUT_PUT_IMAGE)

fetch_running_container_id_in_remote_machine:

	@$(eval RUNNING_DOCKER := $(shell ssh -o StrictHostKeyChecking=no $(SERVER_USERNAME)@$(SERVER_IP) "docker ps -aqf name=$(REPOSITORY)"))

	@echo $(RUNNING_DOCKER)

stop_running_instance:
ifeq ($$RUNNING_DOCKER, "")
	@echo "Not running"
	@$(eval STOP_CMD = "echo")
else
	@echo "Stopping running instances"
	@$(eval STOP_CMD = "docker stop $(RUNNING_DOCKER)")
endif

ssh_login_to_machine:

	$(shell ssh -o StrictHostKeyChecking=no -o LogLevel=error -q $(SERVER_USERNAME)@$(SERVER_IP) "export HISTCONTROL=$(HISTCONTROL) && \
    		export AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) &&  export AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY)  && \
            export AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION) &&  $(shell echo $(STOP_CMD)) &&  $(shell echo $(AWS_ECR_LOGIN)) && \
            docker pull $(ECR_URI)/$(REPOSITORY):$(NEW_TAG) && docker run --rm -d -p $(PORT):$(PORT) --name $(CONTAINER_NAME) --env AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) \
            --env AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) --env AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION) $(ECR_URI)/$(REPOSITORY):$(NEW_TAG)")
            
