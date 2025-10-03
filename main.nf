#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ATLS/uvaginome
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/ATLS/uvaginome
----------------------------------------------------------------------------------------
*/
// Logo and pipeline info
log.info """
=======================================================================================
⠀⣠⣴⣿⣿⣿⣿⣶⣦⣴⣶⣶⣿⣿⣶⣶⣶⣤⣶⣿⣿⣿⣿⣶⣄⠀  
⢰⣿⣿⠟⠋⠉⠻⣿⡟⠻⠿⣿⣿⣿⣿⠿⠟⢻⣿⠟⠋⠙⠻⣿⣿⡆    _   ___     ___    ____ ___ _   _  ___  __  __ _____ 
⠸⣿⣿⣶⡄⠀⠀⠘⣿⡄⠀⠀⠀⠀⠀⠀⢠⣿⠃⠀⠀⢠⣶⣿⣿⡇   | | | \\ \\   / / \\  / ___|_ _| \\ | |/ _ \\|  \\/  | ____|
⠀⣿⣿⡿⠛⢷⣀⣀⣿⣿⣄⠀⠀⠀⠀⣠⣿⣿⣄⣀⣴⠋⢿⣿⣿⡆   | | | |\\ \\ / / _ \\| |  _ | ||  \\| | | | | |\\/| |  _| 
⠀⠈⠳⣤⣠⡾⠛⠋⠹⣿⣿⣦⠀⠀⣴⣿⣿⠏⠙⠛⢿⣤⣤⠾⠉    | |_| | \\ V / ___ \\ |_| || || |\\  | |_| | |  | | |__
⠀⠀⠀⠀⠀⠀⠀⠀ ⢹⣿⣿⣧⣼⣿⣿⡏⠀⠀⠀⠀⠀⠀⠀⠀⠀    \\___/   \\_/_/   \\_\\____|___|_| \\_|\\___/|_|  |_|_____|
⠀⠀⠀⠀⠀⠀⠀⠀ ⠈⣿⠁⠉⠉⠁⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀ ⢻⣆⠀⠀⢰⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀ ⠘⣿⠀⠀⣿⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀  ⠈⠀⠀⠁ 
=======================================================================================
"""

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UVAGINOME  } from './workflows/uvaginome'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_uvaginome_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_uvaginome_pipeline'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow ATLS_UVAGINOME {

    take:
    samplesheet // channel: samplesheet read in from --input

    main:

    //
    // WORKFLOW: Run pipeline
    //
    UVAGINOME (
        samplesheet
    )
    emit:
    multiqc_report = UVAGINOME.out.multiqc_report // channel: /path/to/multiqc_report.html
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input
    )

    //
    // WORKFLOW: Run main workflow
    //
    ATLS_UVAGINOME (
        PIPELINE_INITIALISATION.out.samplesheet
    )
    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.outdir,
        params.monochrome_logs,
        ATLS_UVAGINOME.out.multiqc_report
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
