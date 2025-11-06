/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTQC as FASTQC_RAW                                      } from '../modules/nf-core/fastqc/main'
include { FASTQC as FASTQC_PASS                                     } from '../modules/nf-core/fastqc/main'
include { PORECHOP_PORECHOP                                         } from '../modules/nf-core/porechop/porechop/main'
include { FILTLONG                                                  } from '../modules/nf-core/filtlong/main'   
include { KRAKEN2_BUILDSTANDARD                                     } from '../modules/nf-core/kraken2/buildstandard/main'
include { KRAKEN2_KRAKEN2                                           } from '../modules/nf-core/kraken2/kraken2/main'
include { BRACKEN_BUILD                                             } from '../modules/nf-core/bracken/build/main'
include { BRACKEN_BRACKEN                                           } from '../modules/nf-core/bracken/bracken/main'
include { KRAKENTOOLS_KREPORT2KRONA as KRAKENTOOLS_KREPORT2KRONA_KR } from '../modules/nf-core/krakentools/kreport2krona/main'
include { KRONA_KTIMPORTTEXT as KRONA_KTIMPORTTEXT_KR               } from '../modules/nf-core/krona/ktimporttext/main'
include { KRAKENTOOLS_KREPORT2KRONA as KRAKENTOOLS_KREPORT2KRONA_BR } from '../modules/nf-core/krakentools/kreport2krona/main'
include { KRONA_KTIMPORTTEXT as KRONA_KTIMPORTTEXT_BR               } from '../modules/nf-core/krona/ktimporttext/main'
include { MULTIQC                                                   } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap                                          } from 'plugin/nf-schema'
include { paramsSummaryMultiqc                                      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML                                    } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText                                    } from '../subworkflows/local/utils_nfcore_uvaginome_pipeline'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { HOST_DEPLETION } from '../subworkflows/local/host_depletion/main'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow UVAGINOME {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // MODULE: Run FastQC on raw reads
    //
    FASTQC_RAW (
        ch_samplesheet
    ) 
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_RAW.out.zip.collect{it[1]}.ifEmpty([]))
    ch_versions = ch_versions.mix(FASTQC_RAW.out.versions.first())

    //
    // MODULE: Run Porechop
    //
    PORECHOP_PORECHOP (
        ch_samplesheet
    )
    ch_versions = ch_versions.mix(PORECHOP_PORECHOP.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(PORECHOP_PORECHOP.out.log.collect{it[1]}.ifEmpty([]))
    
    //
    // MODULE: Run filtlong
    //
    FILTLONG ( 
        PORECHOP_PORECHOP.out.reads.map { meta, reads -> [ meta, [], reads ] }
    )
    ch_versions = ch_versions.mix(FILTLONG.out.versions)
    // If reads already fall below target after filtering, results are not added to multiqc report
    ch_multiqc_files = ch_multiqc_files.mix(FILTLONG.out.log.collect{it[1]}.ifEmpty([]))

    //
    // MODULE: Run FastQC on QCed reads
    //
    FASTQC_PASS (
        FILTLONG.out.reads
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_PASS.out.zip.collect{it[1]}.ifEmpty([]))
    ch_versions = ch_versions.mix(FASTQC_PASS.out.versions.first())

    // ================================================================
    // CONDITIONAL ROUTING: Host depletion vs Amplicon data
    // ================================================================
    
    // Initialize analysis reads channel
    ch_analysis_ready_reads = Channel.empty()
    
    if (params.amplicon) {
        log.info "Amplicon data: Skipping host depletion"
        // For amplicon data, use QC-passed reads directly
        ch_analysis_ready_reads = FILTLONG.out.reads
        
    } else {
        log.info "Metagenomic data: Running host depletion"
        //
        // SUBWORKFLOW: Run host depletion on non-amplicon reads
        //
        HOST_DEPLETION(
            FILTLONG.out.reads
        )
        ch_versions = ch_versions.mix(HOST_DEPLETION.out.versions)
        ch_multiqc_files = ch_multiqc_files.mix(HOST_DEPLETION.out.multiqc_files)
        
        // Use host-depleted reads for analysis
        ch_analysis_ready_reads = HOST_DEPLETION.out.reads
    }

    // Check if Kraken2 database is provided
    if (!params.kraken2_db) {
        //
        // MODULE: Run Kraken2 buildstandard
        //
        KRAKEN2_BUILDSTANDARD (
            false
        )
        ch_versions = ch_versions.mix(KRAKEN2_BUILDSTANDARD.out.versions)
        ch_kraken2_db = KRAKEN2_BUILDSTANDARD.out.db
    }
    else {
        // Use provided Kraken2 database
        ch_kraken2_db = Channel.value([params.kraken2_db])
    }

    // Check if bracken database is provided
    if (!params.bracken_db) {
        //
        // MODULE: Run Bracken build
        //
        BRACKEN_BUILD (
            ch_kraken2_db
        )
        ch_versions = ch_versions.mix(BRACKEN_BUILD.out.versions)
        ch_bracken_db = BRACKEN_BUILD.out.db
    }
    else {
        // Use provided bracken database
        ch_bracken_db = Channel.value([params.bracken_db])
    }

    // 
    // MODULE: Run Kraken2
    //
    KRAKEN2_KRAKEN2 (
        ch_analysis_ready_reads,
        ch_kraken2_db,
        false,
        false
    )
    ch_versions = ch_versions.mix(KRAKEN2_KRAKEN2.out.versions.first())
    ch_multiqc_files = ch_multiqc_files.mix(KRAKEN2_KRAKEN2.out.report.collect{it[1]}.ifEmpty([]))

    // 
    // MODULE: Run Bracken
    //
    BRACKEN_BRACKEN (
        KRAKEN2_KRAKEN2.out.report,
        ch_bracken_db
    )
    ch_versions = ch_versions.mix(BRACKEN_BRACKEN.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(BRACKEN_BRACKEN.out.txt.collect{it[1]}.ifEmpty([]))

    //
    // MODULE: Run KrakenTools kreport2krona for kraken2
    //
    KRAKENTOOLS_KREPORT2KRONA_KR (
        KRAKEN2_KRAKEN2.out.report
    )
    ch_versions = ch_versions.mix(KRAKENTOOLS_KREPORT2KRONA_KR.out.versions)

    //
    // MODULE: Run Krona ktimporttext for kraken2
    //
    KRONA_KTIMPORTTEXT_KR (
        KRAKENTOOLS_KREPORT2KRONA_KR.out.txt
    )
    ch_versions = ch_versions.mix(KRONA_KTIMPORTTEXT_KR.out.versions)

    //
    // MODULE: Run KrakenTools kreport2krona for bracken
    //
    KRAKENTOOLS_KREPORT2KRONA_BR (
        BRACKEN_BRACKEN.out.txt
    )
    ch_versions = ch_versions.mix(KRAKENTOOLS_KREPORT2KRONA_BR.out.versions)

    //
    // MODULE: Run Krona ktimporttext for bracken
    //
    KRONA_KTIMPORTTEXT_BR (
        KRAKENTOOLS_KREPORT2KRONA_BR.out.txt
    )
    ch_versions = ch_versions.mix(KRONA_KTIMPORTTEXT_BR.out.versions)

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'uvaginome_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
