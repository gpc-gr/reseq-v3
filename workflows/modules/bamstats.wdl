#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0

import "../tools/picard.wdl"
import "../tools/samtools.wdl"


workflow bamstats {

    # --------------------------------------------------------------------------------
    # input
    # --------------------------------------------------------------------------------

    input {
        File reference_fasta
        Array[File] reference_fasta_indexes
        File bam
        File bam_index
        String output_prefix

        Boolean enable_picard_wgs_metrics_autosome = true
        Boolean enable_picard_wgs_metrics_chrX = true
        Boolean enable_picard_wgs_metrics_chrY = true
        Boolean enable_picard_wgs_metrics_mitochondria = true
    }

    # --------------------------------------------------------------------------------
    # samtools
    # --------------------------------------------------------------------------------

    call samtools.idxstats as step0001_samtools_idxstats { input:
        bam = bam,
        bam_index = bam_index,
        idxstats__name = "${output_prefix}.samtools.idxstats"
    }

    # --------------------------------------------------------------------------------
    # picard
    # --------------------------------------------------------------------------------

    call picard.collect_multiple_metrics as step1001_picard_collect_multiple_metrics { input:
        reference_fasta = reference_fasta,
        reference_fasta_indexes = reference_fasta_indexes,
        bam = bam,
        bam_index = bam_index,
        output_prefix = "${output_prefix}.picard"
    }

    if (enable_picard_wgs_metrics_autosome) {
        call picard.collect_wgs_metrics as step1002_picard_collect_wgs_metrics_autosome { input:
            reference_fasta = reference_fasta,
            reference_fasta_indexes = reference_fasta_indexes,
            bam = bam,
            bam_index = bam_index,
            interval = "${reference_fasta}.picard.autosome.interval_list",
            metrics__name = "${output_prefix}.picard.wgs_metrics.autosome"
        }
    }

    if (enable_picard_wgs_metrics_chrX) {
        call picard.collect_wgs_metrics as step1003_picard_collect_wgs_metrics_chrX { input:
            reference_fasta = reference_fasta,
            reference_fasta_indexes = reference_fasta_indexes,
            bam = bam,
            bam_index = bam_index,
            interval = "${reference_fasta}.picard.chrX.interval_list",
            metrics__name = "${output_prefix}.picard.wgs_metrics.chrX"
        }
    }

    if (enable_picard_wgs_metrics_chrY) {
        call picard.collect_wgs_metrics as step1004_picard_collect_wgs_metrics_chrY { input:
            reference_fasta = reference_fasta,
            reference_fasta_indexes = reference_fasta_indexes,
            bam = bam,
            bam_index = bam_index,
            interval = "${reference_fasta}.picard.chrY.interval_list",
            metrics__name = "${output_prefix}.picard.wgs_metrics.chrY"
        }
    }

    if (enable_picard_wgs_metrics_mitochondria) {
        call picard.collect_wgs_metrics as step1005_picard_collect_wgs_metrics_mitochondria { input:
            reference_fasta = reference_fasta,
            reference_fasta_indexes = reference_fasta_indexes,
            bam = bam,
            bam_index = bam_index,
            interval = "${reference_fasta}.picard.mitochondria.interval_list",
            metrics__name = "${output_prefix}.picard.wgs_metrics.mitochondria"
        }
    }

    # --------------------------------------------------------------------------------
    # output
    # --------------------------------------------------------------------------------

    output {
        File samtools_idxstats = step0001_samtools_idxstats.idxstats

        File picard_alignment_summary = step1001_picard_collect_multiple_metrics.alignment_summary
        File picard_insert_size = step1001_picard_collect_multiple_metrics.insert_size
        File picard_quality_distribution = step1001_picard_collect_multiple_metrics.quality_distribution
        File picard_quality_by_cycle = step1001_picard_collect_multiple_metrics.quality_by_cycle
        File picard_base_distribution_by_cycle = step1001_picard_collect_multiple_metrics.base_distribution_by_cycle
        File picard_gc_bias_summary = step1001_picard_collect_multiple_metrics.gc_bias_summary
        File picard_gc_bias_detail = step1001_picard_collect_multiple_metrics.gc_bias_detail
        File picard_bait_bias_summary = step1001_picard_collect_multiple_metrics.bait_bias_summary
        File picard_bait_bias_detail = step1001_picard_collect_multiple_metrics.bait_bias_detail
        File picard_pre_adapter_summary = step1001_picard_collect_multiple_metrics.pre_adapter_summary
        File picard_pre_adapter_detail = step1001_picard_collect_multiple_metrics.pre_adapter_detail

        File? picard_wgs_metrics_autosome = step1002_picard_collect_wgs_metrics_autosome.metrics
        File? picard_wgs_metrics_chrX = step1003_picard_collect_wgs_metrics_chrX.metrics
        File? picard_wgs_metrics_chrY = step1004_picard_collect_wgs_metrics_chrY.metrics
        File? picard_wgs_metrics_mitochondria = step1005_picard_collect_wgs_metrics_mitochondria.metrics
    }

}
