#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0

import "./modules/bam2gvcf.wdl"


workflow GPCReseq_0012_SingleSampleCall_Autosome {

    # ----------------------------------------------------------------------------
    # input
    # ----------------------------------------------------------------------------

    input {
        String batch_id
        File reference_fasta
        File sample_sheet
        String sample_bam_root

        Boolean apply_bqsr = false
        File target_region_list = "${reference_fasta}.regions.autosome.tsv"
    }

    Array[File] reference_fasta_indexes = [
        "${reference_fasta}.fai",
        sub(reference_fasta, ".fa$", ".dict")
    ]

    Array[Object] samples = read_objects(sample_sheet)
    Array[Object] target_regions = read_objects(target_region_list)

    # ----------------------------------------------------------------------------
    # process each sample
    # ----------------------------------------------------------------------------

    scatter (sample in samples) {

        call bam2gvcf.bam2gvcf as step0001_bam2gvcf { input:
            reference_fasta = reference_fasta,
            reference_fasta_indexes = reference_fasta_indexes,
            bam = "${sample_bam_root}/${sample.id}.base.bam",
            bam_index = "${sample_bam_root}/${sample.id}.base.bam.bai",
            bqsr_table = if (apply_bqsr) then "${sample_bam_root}/${sample.id}.base.bam.bqsr.table" else "",
            sample_id = sample.id,
            sample_sex = sample.sex,
            regions = target_regions,
            output_prefix = "${sample.id}.autosome"
        }

    }

    # ----------------------------------------------------------------------------
    # input
    # ----------------------------------------------------------------------------

    output {
        Array[Array[File]] gvcfs = step0001_bam2gvcf.gvcfs
        Array[Array[File]] gvcf_indexes = step0001_bam2gvcf.gvcf_indexes
    }

}
