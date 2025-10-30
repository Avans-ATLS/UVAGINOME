/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MINIMAP2_ALIGN                } from '../modules/nf-core/minimap2/align/main'
include { MINIMAP2_INDEX                } from '../modules/nf-core/minimap2/index/main'
include { SAMTOOLS_FLAGSTAT             } from '../modules/nf-core/samtools/flagstat/main' 
include { SAMTOOLS_VIEW                 } from '../modules/nf-core/samtools/view/main'
include { SAMTOOLS_FASTQ                } from '../modules/nf-core/samtools/fastq/main'
include { FASTQC as FASTQC_UNMAPPED     } from '../modules/nf-core/fastqc/main'

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
    ch_minimap2_index = Channel.empty()
    ch_minimap2_out = Channel.empty()
    ch_unmapped_reads = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // Check if Minimap2 index is provided
    if (!params.minimap2_index) {
        //
        // MODULE: Run Minimap2 index
        //
        MINIMAP2_INDEX(
            ch_fasta
        )
        ch_versions = ch_versions.mix(MINIMAP2_INDEX.out.versions)
        ch_minimap2_index = MINIMAP2_INDEX.out.index
    }
    else {
        // Use provided Minimap2 index if provided
        ch_minimap2_index = Channel.value([[id:'input_genome_index'], params.minimap2_index])
    }

    //
    // MODULE: Run Minimap2 align
    //
    MINIMAP2_ALIGN(
        // FILTLONG.out.reads,
        // PORECHOP_PORECHOP.out.reads,
        ch_samplesheet,
        ch_minimap2_index,
        true,
        "bai",
        false,
        false
    )
    ch_versions = ch_versions.mix(MINIMAP2_ALIGN.out.versions.first())
    // Create channel with mapping outputs, metadata and empty list for reference
    ch_minimap2_out = MINIMAP2_ALIGN.out.bam.map {meta, reads ->[meta, reads, []] }

    //
    // MODULE: Run Samtools flagstat
    //
    SAMTOOLS_FLAGSTAT (
        ch_minimap2_out
    )
    ch_versions = ch_versions.mix(SAMTOOLS_FLAGSTAT.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(SAMTOOLS_FLAGSTAT.out.flagstat.collect{it[1]}.ifEmpty([]))

    //
    // MODULE: Run Samtools view to extract unmapped reads
    //
    SAMTOOLS_VIEW (
        ch_minimap2_out,
        // Empty list for reference fasta and meta
        [[],[]],
        // Empty list for qname
        []
    )
    ch_versions = ch_versions.mix(SAMTOOLS_VIEW.out.versions)
    ch_unmapped_reads = SAMTOOLS_VIEW.out.bam

    //
    // MODULE: Run Samtools fastq to convert unmapped reads to FASTQ
    //
    SAMTOOLS_FASTQ (
        ch_unmapped_reads, 
        false 
        )
    ch_versions = ch_versions.mix(SAMTOOLS_FASTQ.out.versions)

    // 
    // MODULE: Run FastQC on unmapped reads
    //
    FASTQC_UNMAPPED (
        SAMTOOLS_FASTQ.out.fastq
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_UNMAPPED.out.zip.collect{it[1]}.ifEmpty([]))
    ch_versions = ch_versions.mix(FASTQC_UNMAPPED.out.versions.first())

    emit:
    reads         = SAMTOOLS_FASTQ.out.other       // Non-host reads for downstream analysis
    versions      = ch_versions                    // Software versions
    multiqc_files = ch_multiqc_files               // Files for MultiQC
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/