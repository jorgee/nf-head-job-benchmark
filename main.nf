
nextflow.enable.dsl=2


params.meta_pipeline = 'jorgee/nf-head-job-benchmark'
params.meta_memory_values = [ '7800MB' ]
params.meta_cpus = 4
params.meta_virtual_threads_values = [false]

params.meta_download = false
params.meta_download_profiles = [
    'index_large'
]

params.meta_upload = false
params.meta_upload_counts = [50]
params.meta_upload_sizes = ['1G']
params.meta_upload_trials = 1

params.download_index = "$baseDir/index-small.txt"

params.upload_count = 4
params.upload_size = '10G'
params.upload_prefix = 's3://jorgee-eu-west1-test1/test-data'

params.meta_fs = false
params.meta_fs_trials = 5
params.fs_prefix = 's3://jorgee-eu-west1-test2/test-data'

process download_file {
    input:
    path x

    script:
    """
    ls -lah
    """
}

workflow download {
    Channel.fromPath(params.download_index)
      | splitText
      | map { it.trim() }
      | download_file
}

process download_meta {
    label 'meta'
    tag { profile }

    input:
    val profile

    script:
    """
    # print java memory options
    java -XX:+PrintFlagsFinal -version | grep 'HeapSize\\|RAM'

    # run pipeline
    set +e
    nextflow run ${params.meta_pipeline} -latest -entry download -profile ${profile}
    RESULT=\$?
    if [ \$RESULT -eq 0 ]; then
      echo success
    else
      cat .nextflow.log
    fi
    exit \$RESULT
    """
}


process upload_random_file {
    publishDir "${params.upload_prefix}-${params.upload_count}-${params.upload_size}/"

    input:
    val count
    val size

    output:
    path 'upload-*'

    script:
    """
    for index in `seq $count` ; do
        dd if=/dev/random of=upload-${size}-\${index}.data bs=1 count=0 seek=${size}
    done
    """
}

process upload_random_dir {
    publishDir "${params.upload_prefix}-${params.upload_count}-${params.upload_size}/"

    input:
    val count
    val size

    output:
    path 'upload-dir-*'

    script:
    """
    mkdir upload-dir-${size}
    for index in `seq $count` ; do
        dd if=/dev/random of=upload-dir-${size}/\${index}.data bs=1 count=0 seek=${size}
    done
    """
}

workflow upload {
    upload_random_file(params.upload_count, params.upload_size)
}
workflow upload_dir {
    upload_random_dir(params.upload_count, params.upload_size)
}

process upload_meta {
    label 'meta'
    tag { "n=${n}, size=${size}, vt=${virtual_threads}" }

    input:
    each n
    each size
    each virtual_threads
    each trial

    script:
    """
    # print java memory options
    java -XX:+PrintFlagsFinal -version | grep 'HeapSize\\|RAM'

    # force virtual threads setting to be applied
    rm -f /.nextflow/launch-classpath

    # run pipeline
    set +e
    export NXF_ENABLE_VIRTUAL_THREADS=${virtual_threads}
    nextflow run ${params.meta_pipeline} -latest -entry upload --upload_count ${n} --upload_size '${size}'
    RESULT=\$?
    if [ \$RESULT -eq 0 ]; then
      echo success
    else
      cat .nextflow.log
    fi
    exit \$RESULT
    """
}

process upload_meta_big {
    label 'meta'
    tag { "n=${n}, size=${size}, vt=${virtual_threads}" }

    input:
    each n
    each size
    each virtual_threads
    each trial

    script:
    """
    # print java memory options
    java -XX:+PrintFlagsFinal -version | grep 'HeapSize\\|RAM'

    # force virtual threads setting to be applied
    rm -f /.nextflow/launch-classpath

    # run pipeline
    export NXF_ENABLE_VIRTUAL_THREADS=${virtual_threads}
    nextflow run ${params.meta_pipeline} -latest -entry upload --upload_count ${n} --upload_size '${size}'
    RESULT=\$?
    if [ \$RESULT -eq 0 ]; then
      echo success
    else
      cat .nextflow.log
    fi
    exit \$RESULT
    """
}

process upload_meta_dir {
    label 'meta'
    tag { " dir n=${n}, size=${size}, vt=${virtual_threads}" }

    input:
    each n
    each size
    each virtual_threads
    each trial

    script:
    """
    # print java memory options
    java -XX:+PrintFlagsFinal -version | grep 'HeapSize\\|RAM'

    # force virtual threads setting to be applied
    rm -f /.nextflow/launch-classpath

    # run pipeline
    export NXF_ENABLE_VIRTUAL_THREADS=${virtual_threads}
    nextflow run ${params.meta_pipeline} -latest -entry upload_dir --upload_count ${n} --upload_size '${size}'
    RESULT=\$?
    if [ \$RESULT -eq 0 ]; then
      echo success
    else
      cat .nextflow.log
    fi
    exit \$RESULT
    """
}

process fs_meta {
    label 'meta'
    tag { "vt=${virtual_threads}" }

    input:
    each virtual_threads
    each trial

    script:
    """
    # print java memory options
    java -XX:+PrintFlagsFinal -version | grep 'HeapSize\\|RAM'
    # force virtual threads setting to be applied
    rm -f /.nextflow/launch-classpath

    # run pipeline
    export NXF_ENABLE_VIRTUAL_THREADS=${virtual_threads}
    echo \"aws.region='eu-west-1'\" >> nextflow.config
    echo 'Remove...'
    time nextflow fs rm ${params.fs_prefix}/$trial/*
    echo 'copy file...'
    time nextflow fs cp ${params.upload_prefix}-1-50G/upload-50G-1.data ${params.fs_prefix}/$trial/
    echo 'copy files...'
    time nextflow fs cp ${params.upload_prefix}-50-1G/upload-1G/* ${params.fs_prefix}/$trial/
    echo 'copy dir...'
    time nextflow fs cp ${params.upload_prefix}-50-1G/upload-1G ${params.fs_prefix}/$trial/
    echo 'download file...'
    time nextflow fs cp ${params.upload_prefix}-1-50G/upload-50G-1.data .
    echo 'removing...'
    time rm upload-50G-1.data
    echo 'downloading dir...'
    time nextflow fs cp ${params.upload_prefix}-50-1G/upload-1G .
    echo 'removing...'
    time rm -rf upload-1G
    echo 'downloading files...'
    time nextflow fs cp ${params.upload_prefix}-50-1G/upload-1G/* .
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
        ch_virtual_threads = Channel.fromList(params.meta_virtual_threads_values)
        ch_trials = Channel.of(1 .. params.meta_upload_trials)

        upload_meta(ch_counts, ch_sizes, ch_virtual_threads, ch_trials)
        upload_meta_big(Channel.fromList([1]), Channel.fromList(['50G']), ch_virtual_threads, ch_trials)
        upload_meta_dir(ch_counts, ch_sizes, ch_virtual_threads, ch_trials)
    }
    if ( params.meta_fs ) {
        ch_virtual_threads = Channel.fromList(params.meta_virtual_threads_values)
        ch_trials = Channel.of(1 .. params.meta_upload_trials)
        fs_meta(ch_virtual_threads, ch_trials)
    }
}
