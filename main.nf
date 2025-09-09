
nextflow.enable.dsl=2

params.meta_throughput = [ 10 ]
params.meta_directory_max_concurrency = [100]
params.meta_max_native_mem = [ '1GB' ]
params.meta_max_concurrency = [100]
params.meta_pipeline = 'jorgee/nf-head-job-benchmark'
params.meta_profile = 'local'
params.meta_upload_prefix = 's3://jorgee-eu-west1-test1/test-data'
params.meta_memory_values = [ '7800MB' ]
params.meta_cpus = 4
params.meta_virtual_threads_values = [false]

params.meta_download = false
params.meta_download_profiles = [
    'index_large'
]
params.meta_download_trials = 1

params.meta_upload = false
params.meta_upload_extended = false
params.meta_upload_dir = false
params.meta_upload_tasks = [1]
params.meta_upload_counts = [50]
params.meta_upload_sizes = ['1G']
params.meta_upload_trials = 1

params.download_index = "$baseDir/index-small.txt"

params.upload_task = 1
params.upload_count = 4
params.upload_size = '10G'
params.upload_prefix = 's3://jorgee-eu-west1-test1/test-data'
params.upload_trial = 1

params.meta_fs = false
params.meta_fs_dir = false
params.meta_fs_trials = 5
params.fs_origin = 's3://jorgee-eu-west1-test1/fs-origin-data/test-data'
params.fs_prefix = 's3://jorgee-eu-west1-test2/test-data'
params.meta_fs_dir_counts = [50]
params.meta_fs_dir_sizes = ['1G']

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
    each throughput
    each profile
    each trial

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
    publishDir "${params.upload_prefix}-${params.upload_count}-${params.upload_size}-${params.upload_trial}/"

    input:
    val num_task
    val count
    val size

    output:
    path 'upload-*'

    script:
    """
    for index in `seq $count` ; do
        dd if=/dev/random of=upload-${size}\${index}-${num_task}.data bs=1 count=0 seek=${size}
    done
    """
}

process upload_random_dir {
    publishDir "${params.upload_prefix}-${params.upload_count}-${params.upload_size}-${params.upload_trial}/"

    input:
    val num_task
    val count
    val size

    output:
    path 'upload-dir-*'

    script:
    """
    mkdir upload-dir-${num_task}-${size}
    for index in `seq $count` ; do
        dd if=/dev/random of=upload-dir-${num_task}-${size}/\${index}.data bs=1 count=0 seek=${size}
    done
    """
}

workflow upload {
    ch_tasks = Channel.of(1 .. params.upload_tasks)
    upload_random_file(ch_tasks, params.upload_count, params.upload_size)
}
workflow upload_dir {
    ch_tasks = Channel.of(1 .. params.upload_tasks)
    upload_random_dir(ch_tasks, params.upload_count, params.upload_size)
}

process upload_meta {
    label 'meta'
    tag { "tasks=${tasks} n=${n}, size=${size}, vt=${virtual_threads}" }

    input:
    each tasks
    each n
    each size
    each virtual_threads
    each trial

    script:
    """
    # print java memory options
    java -XX:+PrintFlagsFinal -version | grep 'HeapSize\\|RAM'

    # force virtual threads setting to be applied
    # rm -f /.nextflow/launch-classpath

    # run pipeline
    set +e
    touch .nextflow.log
    tail -f .nextflow.log &
    pid=\$!
    export NXF_ENABLE_VIRTUAL_THREADS=${virtual_threads}
    nextflow run ${params.meta_pipeline}  -latest -profile ${params.meta_profile} -entry upload --upload_tasks ${tasks} --upload_count ${n} --upload_size '${size}' --upload_trial ${trial} --upload_prefix ${params.meta_upload_prefix}
    kill \$pid
    """
}

process upload_meta_big {
    label 'meta'
    tag { "tasks=${tasks} n=${n}, size=${size}, vt=${virtual_threads}" }

    input:
    each tasks
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
    nextflow run ${params.meta_pipeline} -latest -entry upload --upload_tasks ${tasks} --upload_count ${n} --upload_size '${size}' --upload_trial ${trial} --upload_prefix '${params.upload_prefix}'
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
    tag { " dir tasks=${tasks} n=${n}, size=${size}, vt=${virtual_threads} dir_concurrency=${dir_concurrency} thp=${throughput} max_concurrency=${max_concurrency} max_native_mem=${max_native_mem}" }

    input:
    each throughput
    
    each tasks
    each n
    each size
    each virtual_threads
    each dir_concurrency
    each throughput
    each max_concurrency
    each max_native_mem
    each trial

    script:
    """
    # print java memory options
    java -XX:+PrintFlagsFinal -version | grep 'HeapSize\\|RAM'
    echo \"aws.client.transferDirectoryMaxConcurrency=${dir_concurrency}\" >> nextflow.config
    echo \"aws.client.targetThroughputInGbps=${throughput}\" >> nextflow.config
    echo \"aws.client.maxConcurrency=${max_concurrency}\" >> nextflow.config
    echo \"aws.client.maxNativeMemory=${max_native_mem}\" >> nextflow.config
    # force virtual threads setting to be applied
    rm -f /.nextflow/launch-classpath
    
    # run pipeline
    set +e
    export NXF_ENABLE_VIRTUAL_THREADS=${virtual_threads}
    nextflow run ${params.meta_pipeline} -latest -entry upload_dir --upload_tasks ${tasks} --upload_count ${n} --upload_size '${size}' --upload_trial ${trial} --upload_prefix '${params.upload_prefix}'
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
    set +e
    export NXF_ENABLE_VIRTUAL_THREADS=${virtual_threads}
    echo \"aws.region='eu-west-1'\" >> nextflow.config
    echo 'Remove...'
    time nextflow -trace nextflow fs rm ${params.fs_prefix}/$trial/cp/*
    time nextflow -trace nextflow fs rm ${params.fs_prefix}/$trial/up/*
    RESULT=\$?
    if [ \$RESULT -eq 0 ]; then
      echo success
    else
      cat .nextflow.log
      exit \$RESULT
    fi
    echo 'copy file...'
    time nextflow fs cp ${params.fs_origin}-1-50G/upload-50G-1.data ${params.fs_prefix}/$trial/cp/
    RESULT=\$?
    if [ \$RESULT -eq 0 ]; then
      echo success
    else
      cat .nextflow.log
      exit \$RESULT
    fi
    echo 'copy files...'
    time nextflow fs cp '${params.fs_origin}-50-1G/upload-1G/*' ${params.fs_prefix}/$trial/cp/
    RESULT=\$?
    if [ \$RESULT -eq 0 ]; then
      echo success
    else
      cat .nextflow.log
      exit \$RESULT
    fi
    echo 'copy dir...'
    time nextflow fs cp ${params.fs_origin}-50-1G/upload-1G ${params.fs_prefix}/$trial/cp/
    RESULT=\$?
    if [ \$RESULT -eq 0 ]; then
      echo success
    else
      cat .nextflow.log
      exit \$RESULT
    fi
    echo 'download file...'
    time nextflow fs cp ${params.fs_origin}-1-50G/upload-50G-1.data .
    RESULT=\$?
    if [ \$RESULT -eq 0 ]; then
      echo success
    else
      cat .nextflow.log
      exit \$RESULT
    fi
    echo 'upload file...'
    time nextflow fs cp upload-50G-1.data ${params.fs_prefix}/$trial/up/
    RESULT=\$?
    if [ \$RESULT -eq 0 ]; then
      echo success
    else
      cat .nextflow.log
      exit \$RESULT
    fi
    echo 'removing...'
    time rm upload-50G-1.data
    mkdir up-1G-files
    echo 'downloading files...'
    time nextflow fs cp ${params.fs_origin}-50-1G/upload-1G/* \$PWD/up-1G-files/
    RESULT=\$?
    if [ \$RESULT -eq 0 ]; then
      echo success
    else
      cat .nextflow.log
      exit \$RESULT
    fi
    echo 'uploading files...'
    ls -l up-1G-files/*
    time nextflow fs cp 'up-1G-files/*' ${params.fs_prefix}/$trial/up/
    RESULT=\$?
    if [ \$RESULT -eq 0 ]; then
      echo success
    else
      cat .nextflow.log
      exit \$RESULT
    fi
    echo 'removing...'
    time rm -rf up-1G-files
    echo 'downloading dir...'
    time nextflow fs cp ${params.fs_origin}-50-1G/upload-1G .
    RESULT=\$?
    if [ \$RESULT -eq 0 ]; then
      echo success
    else
      cat .nextflow.log
      exit \$RESULT
    fi
    echo 'uploading dir...'
    time nextflow fs cp upload-1G ${params.fs_prefix}/$trial/up/
    RESULT=\$?
    if [ \$RESULT -eq 0 ]; then
      echo success
    else
      cat .nextflow.log
      exit \$RESULT
    fi
    """
}

process fs_meta_dir {
    label 'meta'
    tag { @vt=${virtual_threads} dir_concurrency=${dir_concurrency} thp=${throughput} max_concurrency=${max_concurrency} max_native_mem=$max_native_mem" }

    input:
    each count
    each size
    each virtual_threads
    each dir_concurrency
    each throughput
    each max_concurrency
    each max_native_mem
    each trial

    output:
    path('.nextflow.log*')
    path('*.hprof'), optional: true

    script:
    """
    export JVM_ARGS='-XX:+HeapDumpOnOutOfMemoryError'
    # print java memory options
    java -XX:+PrintFlagsFinal -version | grep 'HeapSize\\|RAM'
    # force virtual threads setting to be applied
    rm -f /.nextflow/launch-classpath

    # run pipeline
    set +e
    export NXF_ENABLE_VIRTUAL_THREADS=${virtual_threads}
    echo \"aws.region='eu-west-1'\" >> nextflow.config
    echo \"aws.client.transferDirectoryMaxConcurrency=${dir_concurrency}\" >> nextflow.config
    echo \"aws.client.targetThroughputInGbps=${throughput}\" >> nextflow.config
    echo \"aws.client.maxConcurrency=${max_concurrency}\" >> nextflow.config
    echo \"aws.client.maxNativeMemory=${max_native_mem}\" >> nextflow.config
    echo
    echo 'Remove...'
    time nextflow -trace nextflow fs rm ${params.fs_prefix}/$trial/up/*
    
    echo 'creating dir $count $size ...'
    mkdir upload-dir-${concurrency}-$count-$size
    for index in `seq $count` ; do
        dd if=/dev/random of=upload-dir-${concurrency}-$count-$size/\${index}.data bs=1 count=0 seek=$size
    done
    echo 'uploading dir $count $size...'
    time nextflow fs cp upload-dir-${concurrency}-$count-$size ${params.fs_prefix}/$trial/up/
    RESULT=\$?
    if [ \$RESULT -eq 0 ]; then
      echo success
    else
      echo failed
    fi
    rm -rf upload-dir-${concurrency}-$count-$size
    echo 'downloading dir $count $size...'
    time nextflow -trace nextflow fs cp ${params.fs_prefix}/$trial/up/upload-dir-${concurrency}-$count-$size . 
    RESULT=\$?
    if [ \$RESULT -eq 0 ]; then
      echo success
    else
      echo failed
    fi
    """
}


workflow {
    if ( params.meta_download ) {
        ch_profiles = Channel.fromList(params.meta_download_profiles)
        ch_trials = Channel.of(1 .. params.meta_download_trials)
        download_meta(ch_profiles, ch_trials)
    }

    if ( params.meta_upload ) {
        ch_tasks = Channel.fromList(params.meta_upload_tasks)
        ch_counts = Channel.fromList(params.meta_upload_counts)
        ch_sizes = Channel.fromList(params.meta_upload_sizes)
        ch_virtual_threads = Channel.fromList(params.meta_virtual_threads_values)
        ch_trials = Channel.of(1 .. params.meta_upload_trials)

        upload_meta(ch_tasks, ch_counts, ch_sizes, ch_virtual_threads, ch_trials)
        if ( params.meta_upload_extended ) {
            upload_meta_big(Channel.fromList([1]), Channel.fromList([1]), Channel.fromList(['50G']), ch_virtual_threads, ch_trials)
            ch_dir_concurrency = Channel.fromList(params.meta_directory_max_concurrency)
            ch_throughput = Channel.fromList(params.meta_throughput)
            ch_concurrency = Channel.fromList(params.meta_max_concurrency)
            ch_max_native_mem = Channel.fromList(params.meta_max_native_mem)
            upload_meta_dir(ch_tasks, ch_counts, ch_sizes, ch_virtual_threads, ch_dir_concurrency, ch_throughput, ch_concurrency, ch_max_native_mem ch_trials)
        }
    }
    if ( params.meta_upload_dir ) {
        ch_tasks = Channel.fromList(params.meta_upload_tasks)
        ch_counts = Channel.fromList(params.meta_upload_counts)
        ch_sizes = Channel.fromList(params.meta_upload_sizes)
        ch_virtual_threads = Channel.fromList(params.meta_virtual_threads_values)
        ch_trials = Channel.of(1 .. params.meta_upload_trials)
        ch_dir_concurrency = Channel.fromList(params.meta_directory_max_concurrency)
        ch_throughput = Channel.fromList(params.meta_throughput)
        ch_concurrency = Channel.fromList(params.meta_max_concurrency)
        ch_max_native_mem = Channel.fromList(params.meta_max_native_mem)
        upload_meta_dir(ch_tasks, ch_counts, ch_sizes, ch_virtual_threads, ch_dir_concurrency, ch_throughput, ch_concurrency, ch_max_native_mem ch_trials)
    }

    if ( params.meta_fs ) {
        ch_virtual_threads = Channel.fromList(params.meta_virtual_threads_values)
        ch_trials = Channel.of(1 .. params.meta_fs_trials)
        fs_meta(ch_virtual_threads, ch_trials)
    }
    if ( params.meta_fs_dir ) {
        ch_dir_concurrency = Channel.fromList(params.meta_directory_max_concurrency)
        ch_throughput = Channel.fromList(params.meta_throughput)
        ch_concurrency = Channel.fromList(params.meta_max_concurrency)
        ch_max_native_mem = Channel.fromList(params.meta_max_native_mem)
        ch_virtual_threads = Channel.fromList(params.meta_virtual_threads_values)
        ch_trials = Channel.of(1 .. params.meta_fs_trials)
        ch_counts = Channel.fromList(params.meta_fs_dir_counts)
        ch_sizes = Channel.fromList(params.meta_fs_dir_sizes)
        fs_meta_dir(ch_counts, ch_sizes, ch_virtual_threads, ch_dir_concurrency, ch_throughput, ch_concurrency, ch_max_native_mem, ch_trials )
    }
}
