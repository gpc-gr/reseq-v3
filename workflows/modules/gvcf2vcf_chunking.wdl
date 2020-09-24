#
#
#

version 1.0

import "../tools/gpc.wdl"
import "./gvcf2vcf_direct.wdl"


workflow gvcf2vcf_chunking {

    # ----------------------------------------------------------------------------
    # input
    # ----------------------------------------------------------------------------

    input {
        File reference_fasta
        Array[File] reference_fasta_indexes

        Array[File] gvcfs
        Array[File] gvcf_indexes

        String contig_id
        String contig_start
        String contig_end

        Int chunk_size
        Int chunk_overlap

        String vcf__name
    }

    # ----------------------------------------------------------------------------
    #
    # ----------------------------------------------------------------------------

    call gpc.enumerate_joint_genotyping_chunks as step0001_enumerate_joint_genotyping_chunks { input:
        start = contig_start,
        end = contig_end,
        size = chunk_size
    }

    scatter (chunk in step0001_enumerate_joint_genotyping_chunks.chunks) {
        call gvcf2vcf_direct.gvcf2vcf_direct as step0002_joint_genotyping { input:
            reference_fasta = reference_fasta,
            reference_fasta_indexes = reference_fasta_indexes,
            gvcfs = gvcfs,
            gvcf_indexes = gvcf_indexes,
            region = "${contig_id}:${chunk.start}-${chunk.end}",
            interval_padding = chunk_overlap,
            vcf__name = sub(vcf__name, ".vcf.gz$", ".chunk${chunk.index}.vcf.gz")
        }
    }

    call gpc.check_joint_genotyping_chunk_consistency as step0003_check_joint_genotyping_chunk_consistency { input:
        chunk_vcfs = step0002_joint_genotyping.vcf,
        chunk_vcf_indexes = step0002_joint_genotyping.vcf_index,
        inconsistent_variant_table__name = sub(vcf__name, ".vcf.gz", ".joint_genotyping.inconsistent_variants.tsv")
    }

    call gpc.concat_chunk_vcfs as step0004_concat_joint_genotyping_chunks { input:
        chunk_vcfs = step0002_joint_genotyping.vcf,
        chunk_vcf_indexes = step0002_joint_genotyping.vcf_index,
        inconsistent_variant_table = step0003_check_joint_genotyping_chunk_consistency.inconsistent_variant_table,
        combined_vcf__name = vcf__name
    }

    # ----------------------------------------------------------------------------
    # output
    # ----------------------------------------------------------------------------

    output {
        File inconsistent_variant_table = step0003_check_joint_genotyping_chunk_consistency.inconsistent_variant_table

        File vcf = step0004_concat_joint_genotyping_chunks.combined_vcf
        File vcf_index = step0004_concat_joint_genotyping_chunks.combined_vcf_index
    }

}
