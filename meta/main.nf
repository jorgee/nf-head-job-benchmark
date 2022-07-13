
params.pipeline = 'bentsherman/nf-s3-stress-stage'

params.download = true
params.download_profiles = [
    "full",
    "index10",
    // "single",
    "small"
]

params.upload = false
params.upload_counts = [1, 4, 10]
params.upload_sizes = ['100M', '1G', '10G']


process download {
    tag { profile }

    input:
        val profile

    script:
    """
    nextflow run ${params.pipeline} -entry download -profile ${profile}
    """
}


process upload {
    tag { "${n}, ${size}" }

    input:
         each n
         each size

    script:
    """
    nextflow run ${params.pipeline} -entry upload --upload_count ${n} --upload_size '${size}'
    """
}


workflow {
    if ( params.download ) {
        Channel.fromList(params.download_profiles) | download
    }

    if ( params.upload ) {
        ch_counts = Channel.fromList(params.upload_counts)
        ch_sizes = Channel.fromList(params.upload_sizes)

        upload(ch_counts, ch_sizes)
    }
}
