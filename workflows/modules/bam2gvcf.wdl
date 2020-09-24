#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0

import "../tools/gatk3.wdl"


workflow bam2gvcf {

    # ----------------------------------------------------------------------------
    #
    # ----------------------------------------------------------------------------

    input {
        File reference_fasta
        Array[File] reference_fasta_indexes
        File bam
        File bam_index
        String? bqsr_table
        String sample_id
        Int sample_sex
        Array[Object] regions
        String output_prefix
    }

    # ----------------------------------------------------------------------------
    #
    # ----------------------------------------------------------------------------

    scatter (region in regions) {

        if (defined(bqsr_table) && bqsr_table != "") {
            call gatk3.haplotype_caller_gvcf as step0001_haplotype_caller_with_bqsr { input:
                reference_fasta = reference_fasta,
                reference_fasta_indexes = reference_fasta_indexes,
                bam = bam,
                bam_index = bam_index,
                bqsr_table = bqsr_table,
                interval = "${region.contig}:${region.start}-${region.end}",
                ploidy = (if (sample_sex == 1) then region.male_ploidy else region.female_ploidy),
                gvcf__name = "${output_prefix}.${region.name}.bqsr.g.vcf.gz"
            }
        }

        if (!defined(bqsr_table) || bqsr_table == "") {
            call gatk3.haplotype_caller_gvcf as step0001_haplotype_caller_without_bqsr { input:
                reference_fasta = reference_fasta,
                reference_fasta_indexes = reference_fasta_indexes,
                bam = bam,
                bam_index = bam_index,
                interval = "${region.contig}:${region.start}-${region.end}",
                ploidy = (if (sample_sex == 1) then region.male_ploidy else region.female_ploidy),
                gvcf__name = "${output_prefix}.${region.name}.g.vcf.gz"
            }
        }

    }

    # ----------------------------------------------------------------------------
    # output
    # ----------------------------------------------------------------------------

    output {
        Array[File] gvcfs = if (defined(bqsr_table) && bqsr_table != "")
            then select_all(step0001_haplotype_caller_with_bqsr.gvcf)
            else select_all(step0001_haplotype_caller_without_bqsr.gvcf)
        Array[File] gvcf_indexes = if (defined(bqsr_table) && bqsr_table != "")
            then select_all(step0001_haplotype_caller_with_bqsr.gvcf_index)
            else select_all(step0001_haplotype_caller_without_bqsr.gvcf_index)
    }

}
