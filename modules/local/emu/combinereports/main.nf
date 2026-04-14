process EMU_COMBINEREPORTS {
    tag "combine_outputs"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/66/66a9b54eaa307623ad2900c87069a5731bf3c3e91f855303aa70476f9535640f/data'
        : 'community.wave.seqera.io/library/emu:3.6.2--0adcfa4809f061f6'}"

    input:
    path(reports, stageAs: "emu_combined/*")

    output:
    path "emu_combined/emu-combined-*.tsv", emit: combined_report
    tuple val("${task.process}"), val('emu'), eval('emu --version 2>&1 | sed "s/^.*emu //; s/Using.*$//"'), topic: versions, emit: versions_emu

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def rank = task.ext.rank ?: 'tax_id'
    """
    emu \\
        combine-outputs \\
        ${args} \\
        emu_reports \\
        ${rank}
    """

    stub:
    def rank = task.ext.rank ?: 'tax_id'
    """
    touch emu_reports/emu-combined-${rank}.tsv
    """
}
