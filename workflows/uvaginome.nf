/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTQC as FASTQC_RAW                                      } from '../modules/nf-core/fastqc/main' 
include { EMU_ABUNDANCE                                             } from '../modules/nf-core/emu/abundance/main'
include { EMU_COMBINEREPORTS                                        } from '../modules/local/emu/combinereports/main'
include { KRAKEN2_BUILDSTANDARD                                     } from '../modules/nf-core/kraken2/buildstandard/main'
include { KRAKEN2_KRAKEN2                                           } from '../modules/nf-core/kraken2/kraken2/main'
include { KRAKENTOOLS_KREPORT2KRONA as KRAKENTOOLS_KREPORT2KRONA_KR } from '../modules/nf-core/krakentools/kreport2krona/main'
include { KRONA_KTIMPORTTEXT as KRONA_KTIMPORTTEXT_KR               } from '../modules/nf-core/krona/ktimporttext/main'
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

    ch_kraken2_db = Channel.value([params.kraken2_db])

    //
    // MODULE: Run FastQC on raw reads
    //
    FASTQC_RAW (
        ch_samplesheet
    ) 
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_RAW.out.zip.collect{it[1]}.ifEmpty([]))

    // ================================================================
    // CONDITIONAL ROUTING: Host depletion vs Amplicon data
    // ================================================================
    
    // Initialize analysis reads channel
    ch_analysis_ready_reads = Channel.empty()
    
    if (params.amplicon) {
        log.info "Amplicon data: Skipping host depletion"
        // For amplicon data, use QC-passed reads directly
        // ch_analysis_ready_reads = FILTLONG.out.reads
        ch_analysis_ready_reads = ch_samplesheet
        
    } else {
        log.info "Metagenomic data: Running host depletion"
        //
        // SUBWORKFLOW: Run host depletion on non-amplicon reads
        //
        HOST_DEPLETION(
            ch_samplesheet
        )
        ch_versions = ch_versions.mix(HOST_DEPLETION.out.versions)
        ch_multiqc_files = ch_multiqc_files.mix(HOST_DEPLETION.out.multiqc_files)
        
        // Use host-depleted reads for analysis
        ch_analysis_ready_reads = HOST_DEPLETION.out.reads
    }

    // Check if users wants to use EMU or Kraken2 for abundance estimation
    if (params.emu) {
        log.info "Using EMU for abundance estimation"
        //
        // MODULE: Run EMU for abundance estimation
        //
        EMU_ABUNDANCE (
            ch_analysis_ready_reads,
            params.emu_db
        )

        // 
        // MODULE: Run EMU combine reports to get combined abundance report
        //
        EMU_COMBINEREPORTS (
            EMU_ABUNDANCE.out.report.map { meta, report -> report }.collect()
        )

    } else {
        log.info "Using Kraken2 for taxonomic classification and abundance estimation"
        // // Check if Kraken2 database is provided
        // if (!params.kraken2_db) {
        //     //
        //     // MODULE: Run Kraken2 buildstandard
        //     //
        //     KRAKEN2_BUILDSTANDARD (
        //         false
        //     )
        //     ch_versions = ch_versions.mix(KRAKEN2_BUILDSTANDARD.out.versions)
        //     ch_kraken2_db = KRAKEN2_BUILDSTANDARD.out.db
        // }
        // else {
        //     // Use provided Kraken2 database
        //     ch_kraken2_db = Channel.value([params.kraken2_db])
        // }

        // 
        // MODULE: Run Kraken2
        //
        KRAKEN2_KRAKEN2 (
            ch_analysis_ready_reads,
            ch_kraken2_db,
            false,
            false
        )
        ch_multiqc_files = ch_multiqc_files.mix(KRAKEN2_KRAKEN2.out.report.collect{it[1]}.ifEmpty([]))

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
    }

    //
    // Collate and save software versions
    //
    def topic_versions = Channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'test_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect().map { files ->
            def configs = []
            if (params.multiqc_config) {
                configs.add(file(params.multiqc_config, checkIfExists: true))
            }
            configs.add(file("$projectDir/assets/multiqc_config.yml", checkIfExists: true))
            def logo = params.multiqc_logo ? file(params.multiqc_logo, checkIfExists: true) : []
            [[id: 'multiqc'], files, configs, logo, [], []]
        }
    )

    emit:multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//  //
//     // Collate and save software versions
//     //
//     def topic_versions = Channel.topic("versions")
//         .distinct()
//         .branch { entry ->
//             versions_file: entry instanceof Path
//             versions_tuple: true
//         }

//     def topic_versions_string = topic_versions.versions_tuple
//         .map { process, tool, version ->
//             [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
//         }
//         .groupTuple(by:0)
//         .map { process, tool_versions ->
//             tool_versions.unique().sort()
//             "${process}:\n${tool_versions.join('\n')}"
//         }

//     softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
//         .mix(topic_versions_string)
//         .collectFile(
//             storeDir: "${params.outdir}/pipeline_info",
//             name: 'nf_core_'  +  'test_software_'  + 'mqc_'  + 'versions.yml',
//             sort: true,
//             newLine: true
//         ).set { ch_collated_versions }


//     //
//     // MODULE: MultiQC
//     //
//     ch_multiqc_config        = channel.fromPath(
//         "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
//     ch_multiqc_custom_config = params.multiqc_config ?
//         channel.fromPath(params.multiqc_config, checkIfExists: true) :
//         channel.empty()
//     ch_multiqc_logo          = params.multiqc_logo ?
//         channel.fromPath(params.multiqc_logo, checkIfExists: true) :
//         channel.empty()

//     summary_params      = paramsSummaryMap(
//         workflow, parameters_schema: "nextflow_schema.json")
//     ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
//     ch_multiqc_files = ch_multiqc_files.mix(
//         ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
//     ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
//         file(params.multiqc_methods_description, checkIfExists: true) :
//         file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
//     ch_methods_description                = channel.value(
//         methodsDescriptionText(ch_multiqc_custom_methods_description))

//     ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
//     ch_multiqc_files = ch_multiqc_files.mix(
//         ch_methods_description.collectFile(
//             name: 'methods_description_mqc.yaml',
//             sort: true
//         )
//     )

//     MULTIQC (
//         ch_multiqc_files.collect(),
//         ch_multiqc_config.toList(),
//         ch_multiqc_custom_config.toList(),
//         ch_multiqc_logo.toList(),
//         [],
//         []
//     )

//     emit:multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
//     versions       = ch_versions                 // channel: [ path(versions.yml) ]
