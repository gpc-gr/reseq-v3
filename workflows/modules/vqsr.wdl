#
#
#

version 1.0

import "../tools/gatk3.wdl"


workflow vqsr {

    # ----------------------------------------------------------------------------
    # input
    # ----------------------------------------------------------------------------

    input {
        File reference_fasta
        Array[File] reference_fasta_indexes

        Array[File] vcfs
        Array[File] vcf_indexes

        Array[String] snv_tranches
        Array[String] snv_annotations
        Array[String] snv_resources
        Int snv_max_gaussians
        String snv_threshold

        Array[String] indel_tranches
        Array[String] indel_annotations
        Array[String] indel_resources
        Int indel_max_gaussians
        String indel_threshold

        String output_prefix
    }

    # ----------------------------------------------------------------------------
    # build recalibration table
    # ----------------------------------------------------------------------------

    call gatk3.variant_recalibrator as step0001_variant_recalibrator_snv { input:
        reference_fasta = reference_fasta,
        reference_fasta_indexes = reference_fasta_indexes,
        vcfs = vcfs,
        vcf_indexes = vcf_indexes,
        tranches = snv_tranches,
        annotations = snv_annotations,
        resources = snv_resources,
        max_gaussians = snv_max_gaussians,
        mode = "SNP",
        output_prefix = "${output_prefix}.vqsr.snv"
    }

    call gatk3.variant_recalibrator as step0002_variant_recalibrator_indel { input:
        reference_fasta = reference_fasta,
        reference_fasta_indexes = reference_fasta_indexes,
        vcfs = vcfs,
        vcf_indexes = vcf_indexes,
        tranches = indel_tranches,
        annotations = indel_annotations,
        resources = indel_resources,
        max_gaussians = indel_max_gaussians,
        mode = "INDEL",
        output_prefix = "${output_prefix}.vqsr.indel"
    }

    # ----------------------------------------------------------------------------
    # apply VQSR
    # ----------------------------------------------------------------------------

    scatter (pair in zip(vcfs, vcf_indexes)) {
        call gatk3.apply_recalibration as step0003_apply_recalibration { input:
            reference_fasta = reference_fasta,
            reference_fasta_indexes = reference_fasta_indexes,
            vcf = pair.left,
            vcf_index = pair.right,
            snv_recal = step0001_variant_recalibrator_snv.recal,
            snv_tranches = step0001_variant_recalibrator_snv.tranches,
            indel_recal = step0002_variant_recalibrator_indel.recal,
            indel_tranches = step0002_variant_recalibrator_indel.tranches,
            snv_filter_level = snv_threshold,
            indel_filter_level = indel_threshold,
            result_vcf__name = sub(basename(pair.left), ".vcf.gz$", ".vqsr_${snv_threshold}_${indel_threshold}.vcf.gz")
        }
    }

    # ----------------------------------------------------------------------------
    # output
    # ----------------------------------------------------------------------------

    output {
        File snv_recal_table = step0001_variant_recalibrator_snv.recal
        File snv_tranches_table = step0001_variant_recalibrator_snv.tranches
        File snv_rscript = step0001_variant_recalibrator_snv.rscript

        File indel_recal_table = step0002_variant_recalibrator_indel.recal
        File indel_tranches_table = step0002_variant_recalibrator_indel.tranches
        File indel_rscript = step0002_variant_recalibrator_indel.rscript

        Array[File] result_vcfs = step0003_apply_recalibration.result_vcf
        Array[File] result_vcf_indexes = step0003_apply_recalibration.result_vcf_index
    }

}
