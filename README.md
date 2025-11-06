# ATLS/UVAGINOME


[![Nextflow](https://img.shields.io/badge/version-%E2%89%A524.10.5-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-3.3.2-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/3.3.2)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/ATLS/uvaginome)

## Introduction

**ATLS/UVAGINOME** is a bioinformatics pipeline for ONT sequencing reads that can perform host depletion based on a reference genome and taxonomically classifies the remaining reads. It also performs QC on your reads, and creates visualizations of the found taxonomy. The pipeline can handle amplicon data (e.g. 16S or ITS), and it will skip the host depletion step.

A visual overview of the steps performed by the pipeline:

![Metrochart](https://github.com/Avans-ATLS/UVAGINOME/blob/dev/uvaginome_pipeline_ampliconswitch_metrochart.png)

The steps in the pipeline are:
1. Quality check with FastQC
2. Adapter trimming with Porechop
3. Quality trimming/filtering with Filtlong
4. Quality check with FastQC
5. Optional host depletion:
   1. Optional: Create index of host reference genome with Minimap2
   2. Map reads against host reference genome index with Minimap2
   3. Split mapped and unmapped reads with Samtools
   4. Calculate mapped and unmapped reads stats with Samtools
   5. Quality check of unmapped reads with FastQC
6. Optional: Build standard Kraken2 database with Kraken2
7. Taxonomic classification with Kraken2
8. Optional: Build Bracken database with Bracken
9. Re-calculate relative abundances with Bracken
10. Visualize results with Krona

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.


First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,fastq_1
BRVP_PVPR_0705,BRVP_PVPR_0705.fastq.gz
```

Each row represents a fastq file (single-end).

Now, you can run the pipeline using:

<!-- TODO nf-core: update the following command to include all required parameters for a minimal example -->
For metagenomic data:
```bash
nextflow run ATLS/uvaginome \
   -profile <docker/singularity/conda/institute> \
   --input samplesheet.csv \
   --outdir <OUTDIR>
```
For amplicon data:
```bash
nextflow run ATLS/uvaginome \
   -profile <docker/singularity/conda/institute> \
   --input samplesheet.csv \
   --outdir <OUTDIR> \
   --amplicon
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/usage/getting_started/configuration#custom-configuration-files).

## Credits

ATLS/UVAGINOME was originally written by Birgit Rijvers-van Pruissen.

We thank the following people for their extensive assistance in the development of this pipeline:

<!-- TODO nf-core: If applicable, make list of people who have also contributed -->

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use ATLS/uvaginome for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
