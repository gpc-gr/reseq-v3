#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0

import "./modules/gvcf2vcf_chunking.wdl"
import "./modules/vqsr.wdl"
import "./tools/gpc.wdl"


workflow GPCReseq_0021_JointGenotyping_Chunking {

    # ----------------------------------------------------------------------------
    # input
    # ----------------------------------------------------------------------------

    input {
        String analysis_id

        File reference_fasta
        String target_type
        File sample_sheet
        String sample_gvcf_root

        Boolean bqsr_applied = true
        File target_region_list = "${reference_fasta}.regions.${target_type}.tsv"

        Int chunk_size = 3 * 1000 * 1000
        Int chunk_overlap = 1 * 1000

        Array[String] vqsr_snv_tranches = [
            "100.0", "99.95", "99.9", "99.8", "99.6", "99.5",
            "99.4", "99.3", "99.0", "98.0", "97.0"
        ]
        Array[String] vqsr_snv_annotations = [
            "QD", "MQ", "MQRankSum", "ReadPosRankSum", "FS", "SOR", "DP", "InbreedingCoeff"
        ]
        Array[String] vqsr_snv_resources = []
        String vqsr_snv_threshold = "99.5"
        Int vqsr_snv_max_gaussians = 8

        Array[String] vqsr_indel_tranches = [
            "100.0", "99.95", "99.9", "99.5", "99.0", "97.0", "96.0",
            "95.0", "94.0", "93.0", "92.0", "91.0", "90.0"
        ]
        Array[String] vqsr_indel_annotations = [
            "QD", "DP", "FS", "SOR", "ReadPosRankSum", "MQRankSum", "InbreedingCoeff"
        ]
        Array[String] vqsr_indel_resources = []
        String vqsr_indel_threshold = "99.0"
        Int vqsr_indel_max_gaussians = 4
    }

    Array[File] reference_fasta_indexes = [
        "${reference_fasta}.fai",
        sub(reference_fasta, ".fa$", ".dict")
    ]

    Array[Object] target_regions = [read_objects(target_region_list)[0]]
    Array[Object] samples = read_objects(sample_sheet)
    Boolean apply_vqsr = (length(vqsr_snv_resources) > 0 && length(vqsr_indel_resources) > 0)

    # ----------------------------------------------------------------------------
    # perform joint genotyping
    # ----------------------------------------------------------------------------

    scatter (region in target_regions) {

        call gpc.collect_sample_files as step0001_collect_gvcfs { input:
            sample_sheet = sample_sheet,
            sample_file_root = sample_gvcf_root,
            sample_file_suffix = ".${target_type}.${region.name}" + (if (bqsr_applied) then ".bqsr" else "") + ".g.vcf.gz",
            sample_file_index_extension = ".tbi"
        }

        call gvcf2vcf_chunking.gvcf2vcf_chunking as step0001_joint_genotyping { input:
            reference_fasta = reference_fasta,
            reference_fasta_indexes = reference_fasta_indexes,
            gvcfs = step0001_collect_gvcfs.files,
            gvcf_indexes = step0001_collect_gvcfs.file_indexes,
            contig_id = region.contig,
            contig_start = region.start,
            contig_end = region.end,
            chunk_size = chunk_size,
            chunk_overlap = chunk_overlap,
            vcf__name = "${analysis_id}.${region.name}.vcf.gz"
        }

    }

    # ----------------------------------------------------------------------------
    # perform VQSR filtering
    # ----------------------------------------------------------------------------

    if (apply_vqsr) {

        call vqsr.vqsr as step0002_vqsr { input:
            reference_fasta = reference_fasta,
            reference_fasta_indexes = reference_fasta_indexes,
            vcfs = step0001_joint_genotyping.vcf,
            vcf_indexes = step0001_joint_genotyping.vcf_index,
            snv_tranches = vqsr_snv_tranches,
            snv_annotations = vqsr_snv_annotations,
            snv_resources = vqsr_snv_resources,
            snv_max_gaussians = vqsr_snv_max_gaussians,
            snv_threshold = vqsr_snv_threshold,
            indel_tranches = vqsr_indel_tranches,
            indel_annotations = vqsr_indel_annotations,
            indel_resources = vqsr_indel_resources,
            indel_max_gaussians = vqsr_indel_max_gaussians,
            indel_threshold = vqsr_indel_threshold,
            output_prefix = analysis_id
        }

    }

    # ----------------------------------------------------------------------------
    # output
    # ----------------------------------------------------------------------------

    output {
        Array[File]? vcfs = if (apply_vqsr)
            then step0002_vqsr.result_vcfs
            else step0001_joint_genotyping.vcf
        Array[File]? vcf_indexes = if (apply_vqsr)
            then step0002_vqsr.result_vcf_indexes
            else step0001_joint_genotyping.vcf_index

        Array[File] vqsr_snv_recal_table = if (apply_vqsr)
            then select_all([step0002_vqsr.snv_recal_table])
            else []
        Array[File] vqsr_snv_tranches_table = if (apply_vqsr)
            then select_all([step0002_vqsr.snv_tranches_table])
            else []
        Array[File] vqsr_snv_rscript = if (apply_vqsr)
            then select_all([step0002_vqsr.snv_rscript])
            else []

        Array[File] vqsr_indel_recal_table = if (apply_vqsr)
            then select_all([step0002_vqsr.indel_recal_table])
            else []
        Array[File] vqsr_indel_tranches_table = if (apply_vqsr)
            then select_all([step0002_vqsr.indel_tranches_table])
            else []
        Array[File] vqsr_indel_rscript = if (apply_vqsr)
            then select_all([step0002_vqsr.indel_rscript])
            else []
    }

}
