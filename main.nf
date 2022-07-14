
nextflow.enable.dsl=2


params.meta_pipeline = 'bentsherman/nf-head-job-benchmark'
params.meta_memory_values = [1.GB, 2.GB, 4.GB, 8.GB, 16.GB]

params.meta_download = true
params.meta_download_profiles = [
    "index_small",
    // "index_medium",
    // "index_large"
]

params.meta_upload = false
params.meta_upload_counts = [1, 4, 10]
params.meta_upload_sizes = ['100M', '1G', '10G']

params.download_index = "$baseDir/index-small.txt"

params.upload_count = 4
params.upload_size = '10G'
params.upload_bucket = 's3://nextflow-ci-dev/data/'


process download_foo {
    input:
        path x

    script:
    """
    ls -lah
    """
}

process download_bar {
    input:
        path x

    script:
    """
    ls -lah
    """
}

workflow download {
    Channel.fromPath(params.download_index) \
      | splitText \
      | map { it.trim() } \
      | set { ch_files }

    download_foo(ch_files)
    download_bar(ch_files)
}

process download_meta {
    label 'meta'
    tag { profile }

    input:
        val profile

    script:
    """
    nextflow run ${params.meta_pipeline} -latest -entry download -profile ${profile}
    """
}


process upload_random_file {
    publishDir params.upload_bucket

    input:
        val index

    output:
        path '*.data'

    script:
    """
    dd if=/dev/zero of=upload-${params.upload_size}-${index}.data bs=1 count=0 seek=${params.upload_size}
    """
}

workflow upload {
    Channel.of(1..params.upload_count) | upload_random_file
}

process upload_meta {
    label 'meta'
    tag { "${n}, ${size}" }

    input:
         each n
         each size

    script:
    """
    nextflow run ${params.meta_pipeline} -latest -entry upload --upload_count ${n} --upload_size '${size}'
    """
}


workflow {
    if ( params.meta_download ) {
        ch_profiles = Channel.fromList(params.meta_download_profiles)
        
        download_meta(ch_profiles)
    }

    if ( params.meta_upload ) {
        ch_counts = Channel.fromList(params.meta_upload_counts)
        ch_sizes = Channel.fromList(params.meta_upload_sizes)

        upload_meta(ch_counts, ch_sizes)
    }
}
