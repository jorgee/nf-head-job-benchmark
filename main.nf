nextflow.enable.dsl=2

params.index = "$baseDir/index-full.txt"
params.upload_count = 4
params.upload_size = '10G'
params.upload_bucket = 's3://nextflow-ci-dev/data/'


workflow {
  download()
  upload()
}

workflow download {
  channel.fromPath(params.index) \
    | splitText \
    | map { it.trim() } \
    | set { files_ch }

  foo(files_ch)
  bar(files_ch)
}

workflow upload {
  channel.of(1..params.upload_count) | uploadRandomFile
}

process foo {
  input:
    path x
  """
  ls -lah
  """
}

process bar {
  input:
    path x
  """
  ls -lah
  """
}

process uploadRandomFile {
  publishDir params.upload_bucket
  output:
  path '*.data'
  """
  dd if=/dev/zero of=myfile-${params.upload_size}.data bs=1 count=0 seek=${params.upload_size}
  """
}
