# nf-head-job-benchmark

This Nextflow pipeline can be used to benchmark the resource usage of the Nextflow head job.

Benchmark tasks include:
- `--meta_download`: download files from S3
- `--meta_upload`: upload files to S3
- `--meta_dataproc`: (WIP) process large dataset with native code

## Usage 

Refer to `main.nf` for the list of available meta-pipeline parameters.

```bash
nextflow run bentsherman/nf-head-job-benchmark [--meta_download] [--meta_upload]
```

To run a specific workflow:

```bash
nextflow run bentsherman/nf-head-job-benchmark -entry upload --upload_count 1000 --upload_size '100MB'
```
