
version ?= "22.07.1-edge"

build:
	cp ../../nextflow-io_nextflow/build/releases/nextflow-${version}-all nextflow
	docker build -t bentsherman/nextflow:${version} .

push: build
	docker push bentsherman/nextflow:${version}
