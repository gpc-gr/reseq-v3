#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0


task collect_multiple_metrics {
    input {
        File reference_fasta
        Array[File] reference_fasta_indexes
        File bam
        File bam_index
        String output_prefix
    }

    runtime {
        cpu: 1
        memory: "32G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        picard -Xmx${GE_MEMORY_GB:-1}G CollectMultipleMetrics\
            INPUT=~{bam}\
            OUTPUT=~{output_prefix}\
            REFERENCE_SEQUENCE=~{reference_fasta}\
            PROGRAM=null\
            PROGRAM=CollectAlignmentSummaryMetrics\
            PROGRAM=CollectInsertSizeMetrics\
            PROGRAM=QualityScoreDistribution\
            PROGRAM=MeanQualityByCycle\
            PROGRAM=CollectBaseDistributionByCycle\
            PROGRAM=CollectGcBiasMetrics\
            PROGRAM=CollectSequencingArtifactMetrics
    >>>

    output {
        File alignment_summary = "${output_prefix}.alignment_summary_metrics"
        File insert_size = "${output_prefix}.insert_size_metrics"
        File quality_distribution = "${output_prefix}.quality_distribution_metrics"
        File quality_by_cycle = "${output_prefix}.quality_by_cycle_metrics"
        File base_distribution_by_cycle = "${output_prefix}.base_distribution_by_cycle_metrics"
        File gc_bias_summary = "${output_prefix}.gc_bias.summary_metrics"
        File gc_bias_detail = "${output_prefix}.gc_bias.detail_metrics"
        File bait_bias_summary = "${output_prefix}.bait_bias_summary_metrics"
        File bait_bias_detail = "${output_prefix}.bait_bias_detail_metrics"
        File pre_adapter_summary = "${output_prefix}.pre_adapter_summary_metrics"
        File pre_adapter_detail = "${output_prefix}.pre_adapter_detail_metrics"
    }
}


task collect_wgs_metrics {
    input {
        File reference_fasta
        Array[File] reference_fasta_indexes
        File bam
        File bam_index
        File interval
        String metrics__name
    }

    runtime {
        cpu: 1
        memory: "32G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        picard -Xmx${GE_MEMORY_GB:-1}G CollectWgsMetrics\
            REFERENCE_SEQUENCE=~{reference_fasta}\
            INPUT=~{bam}\
            INTERVALS=~{interval}\
            OUTPUT=~{metrics__name}
    >>>

    output {
        File metrics = "${metrics__name}"
    }
}


task mark_duplicates {
    input {
        Array[File] source_bams
        String rmdup_bam__name
        String rmdup_metrics__name
    }

    runtime {
        cpu: 1
        memory: "32G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        picard -Xmx${GE_MEMORY_GB:-1}G MarkDuplicates\
            ~{sep=" " prefix("INPUT=", source_bams)}\
            OUTPUT=~{rmdup_bam__name}\
            METRICS_FILE=~{rmdup_metrics__name}\
            COMPRESSION_LEVEL=9\
            CREATE_INDEX=true\
            ASSUME_SORTED=true\
            VALIDATION_STRINGENCY=LENIENT

        mv ~{sub(rmdup_bam__name, ".bam$", ".bai")} ~{rmdup_bam__name}.bai
    >>>

    output {
        File rmdup_bam = "${rmdup_bam__name}"
        File rmdup_bam_index = "${rmdup_bam__name}.bai"
        File rmdup_metrics = "${rmdup_metrics__name}"
    }
}
