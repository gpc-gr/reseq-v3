#
#
#

version 1.0

import "../tools/gatk3.wdl"
import "../tools/gpc.wdl"


workflow gvcf2vcf_direct {

    # ----------------------------------------------------------------------------
    # input
    # ----------------------------------------------------------------------------

    input {
        File reference_fasta
        Array[File] reference_fasta_indexes

        Array[File] gvcfs
        Array[File] gvcf_indexes

        String region
        Int? interval_padding

        String vcf__name
    }

    Int num_gvcf_groups = (length(gvcfs) / 200) + (if (length(gvcfs) % 200 != 0) then 1 else 0)

    # ----------------------------------------------------------------------------
    # joint genotyping
    # ----------------------------------------------------------------------------

    scatter (index in range(num_gvcf_groups)) {
        call gatk3.combine_gvcfs as step0001_combine_gvcfs { input:
            reference_fasta = reference_fasta,
            reference_fasta_indexes = reference_fasta_indexes,
            gvcfs = gvcfs,
            gvcf_indexes = gvcf_indexes,
            size = 200,
            index = index,
            region = region,
            interval_padding = interval_padding,
            combined_gvcf__name = sub(vcf__name, ".vcf.gz$", "g${index}.g.vcf.gz")
        }
    }

    call gatk3.genotype_gvcfs as step1001_joint_genotyping { input:
        reference_fasta = reference_fasta,
        reference_fasta_indexes = reference_fasta_indexes,
        gvcfs = step0001_combine_gvcfs.combined_gvcf,
        gvcf_indexes = step0001_combine_gvcfs.combined_gvcf_index,
        region = region,
        interval_padding = interval_padding,
        vcf__name = vcf__name
    }

    # ----------------------------------------------------------------------------
    # output
    # ----------------------------------------------------------------------------

    output {
        File vcf = step1001_joint_genotyping.vcf
        File vcf_index = step1001_joint_genotyping.vcf_index
    }

}
