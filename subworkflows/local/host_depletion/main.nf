/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { HOSTILE_FETCH                 } from '../../../modules/nf-core/hostile/fetch/main'  
include { HOSTILE_CLEAN                 } from '../../../modules/nf-core/hostile/clean/main' 
include { FASTQC as FASTQC_MAPPED       } from '../../../modules/nf-core/fastqc/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE PARAMS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
if(params.fasta){
    ch_fasta = Channel.fromPath(params.fasta, checkIfExists: true).collect()
        .map{ it -> [[id:it[0].getSimpleName()], it[0]]}
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN SUBWORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow HOST_DEPLETION {

    take:
    ch_reads       // channel: QC passed reads for host depletion
    
    main:
    ch_versions = Channel.empty()
    ch_hostile_index = Channel.empty()
    ch_hostile_out = Channel.empty()
    ch_unmapped_reads = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // Check if hostile index is provided by user
    if (params.hostile_index) {
        log.info "Using user-provided hostile index: ${params.hostile_index}"
        ch_hostile_index = Channel
            .value(tuple("human-t2t-hla", file(params.hostile_index, checkIfExists: true)))
    } else {
        log.info "No hostile index provided. Fetching host genome from NCBI using Hostile fetch."
        HOSTILE_FETCH(
            "human-t2t-hla"
            // minimap2 index arg in conf/modules.config
        )
        ch_versions = ch_versions.mix(HOSTILE_FETCH.out.versions)
        ch_hostile_index = HOSTILE_FETCH.out.reference
    }

    //
    // MODULE: Run Hostile clean to remove host reads
    //
    HOSTILE_CLEAN (
        ch_reads,
        ch_hostile_index
    )
    ch_versions = ch_versions.mix(HOSTILE_CLEAN.out.versions)
    ch_hostile_out = ch_hostile_out.mix(HOSTILE_CLEAN.out.fastq)

    // 
    // MODULE: Run FastQC on mapped reads
    //
    FASTQC_MAPPED (
        ch_hostile_out
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_MAPPED.out.zip.collect{it[1]}.ifEmpty([]))
    // ch_versions = ch_versions.mix(FASTQC_MAPPED.out.versions_fastqc.first())

    emit:
    reads = ch_hostile_out // host depleted reads
    versions      = ch_versions                    // Software versions
    multiqc_files = ch_multiqc_files               // Files for MultiQC
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/