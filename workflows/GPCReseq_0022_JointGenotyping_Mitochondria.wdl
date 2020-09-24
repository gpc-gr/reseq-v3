#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0

import "./modules/gvcf2vcf_direct.wdl"
import "./tools/gpc.wdl"


workflow GPCReseq_0022_JointGenotyping_Mitochondria {

    # ----------------------------------------------------------------------------
    # input
    # ----------------------------------------------------------------------------

    input {
        String analysis_id

        File reference_fasta_original
        File reference_fasta_shifted
        Int reference_fasta_shift_size
        File sample_sheet
        String sample_gvcf_root

        File target_region_list = "${reference_fasta_original}.regions.mitochondria.tsv"
    }

    Array[File] reference_fasta_original_indexes = [
        "${reference_fasta_original}.fai",
        sub(reference_fasta_original, ".fa$", ".dict")
    ]
    Array[File] reference_fasta_shifted_indexes = [
        "${reference_fasta_shifted}.fai",
        sub(reference_fasta_shifted, ".fa$", ".dict")
    ]

    Array[Object] target_regions = read_objects(target_region_list)
    Array[Object] samples = read_objects(sample_sheet)

    # ----------------------------------------------------------------------------
    # perform joint genotyping
    # ----------------------------------------------------------------------------

    scatter (region in target_regions) {

        # ------------------------------------------------------------------------
        # original
        # ------------------------------------------------------------------------

        call gpc.collect_sample_files as step0001_collect_gvcfs_original { input:
            sample_sheet = sample_sheet,
            sample_file_root = sample_gvcf_root,
            sample_file_suffix = ".mitochondria_shifted.${region.name}.g.vcf.gz",
            sample_file_index_extension = ".tbi"
        }

        call gvcf2vcf_direct.gvcf2vcf_direct as step0002_joint_genotyping_original { input:
            reference_fasta = reference_fasta_original,
            reference_fasta_indexes = reference_fasta_original_indexes,
            gvcfs = step0001_collect_gvcfs_original.files,
            gvcf_indexes = step0001_collect_gvcfs_original.file_indexes,
            region = "${region.contig}:${region.start}-${region.end}",
            vcf__name = "${analysis_id}.mitochondria_original.${region.name}.vcf.gz"
        }

        # ------------------------------------------------------------------------
        # shifted
        # ------------------------------------------------------------------------

        call gpc.collect_sample_files as step1001_collect_gvcfs_shifted { input:
            sample_sheet = sample_sheet,
            sample_file_root = sample_gvcf_root,
            sample_file_suffix = ".mitochondria_original.${region.name}.g.vcf.gz",
            sample_file_index_extension = ".tbi"
        }

        call gvcf2vcf_direct.gvcf2vcf_direct as step1002_joint_genotyping_shifted { input:
            reference_fasta = reference_fasta_shifted,
            reference_fasta_indexes = reference_fasta_shifted_indexes,
            gvcfs = step1001_collect_gvcfs_shifted.files,
            gvcf_indexes = step1001_collect_gvcfs_shifted.file_indexes,
            region = "${region.contig}:${region.start}-${region.end}",
            vcf__name = "${analysis_id}.mitochondria_shifted.${region.name}.vcf.gz"
        }

        call gpc.shift_back_mitochondria_vcf as step1003_shift_back_vcf { input:
            contig = region.contig,
            shift_size = reference_fasta_shift_size,
            shifted_vcf = step1002_joint_genotyping_shifted.vcf,
            shifted_vcf_index = step1002_joint_genotyping_shifted.vcf_index,
            shifted_back_vcf__name = "${analysis_id}.mitochondria_shifted_back.${region.name}.vcf.gz"
        }

        # ------------------------------------------------------------------------
        # merge
        # ------------------------------------------------------------------------

        call gpc.check_mitochondria_vcf_consistency as step2001_check_vcf_consistency { input:
            original_vcf = step0002_joint_genotyping_original.vcf,
            original_vcf_index = step0002_joint_genotyping_original.vcf_index,
            shifted_vcf = step1003_shift_back_vcf.shifted_back_vcf,
            shifted_vcf_index = step1003_shift_back_vcf.shifted_back_vcf_index,
            inconsistent_variant_table__name = "${analysis_id}.mitochondria.${region.name}.inconsistent_variants.tsv"
        }

        call gpc.concat_chunk_vcfs as step2002_merge_mitochondria_vcfs { input:
            chunk_vcfs = [step0002_joint_genotyping_original.vcf],
            chunk_vcf_indexes = [step0002_joint_genotyping_original.vcf_index],
            inconsistent_variant_table = step2001_check_vcf_consistency.inconsistent_variant_table,
            combined_vcf__name = "${analysis_id}.mitochondria.${region.name}.vcf.gz"
        }

    }

    # ----------------------------------------------------------------------------
    # output
    # ----------------------------------------------------------------------------

    output {
        Array[File] inconsistent_variant_tables = step2001_check_vcf_consistency.inconsistent_variant_table

        Array[File] vcfs = step2002_merge_mitochondria_vcfs.combined_vcf
        Array[File] vcf_indexes = step2002_merge_mitochondria_vcfs.combined_vcf_index
    }

}
