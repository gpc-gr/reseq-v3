#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0

import "./modules/bam2gvcf.wdl"
import "./modules/fastq2bam.wdl"
import "./tools/gpc.wdl"


workflow GPCReseq_0015_SingleSampleCall_Mitochondria {

    # ----------------------------------------------------------------------------
    # input
    # ----------------------------------------------------------------------------

    input {
        String batch_id
        File reference_fasta_original
        File reference_fasta_shifted
        File sample_sheet
        String sample_bam_root

        File target_region_list = "${reference_fasta_original}.regions.mitochondria.tsv"
    }

    Array[File] reference_fasta_original_indexes = [
        "${reference_fasta_original}.amb",       # bwa
        "${reference_fasta_original}.ann",
        "${reference_fasta_original}.bwt",
        "${reference_fasta_original}.pac",
        "${reference_fasta_original}.sa",
        "${reference_fasta_original}.fai",       # general
        sub(reference_fasta_original, ".fa$", ".dict")
    ]
    Array[File] reference_fasta_shifted_indexes = [
        "${reference_fasta_shifted}.amb",
        "${reference_fasta_shifted}.ann",
        "${reference_fasta_shifted}.bwt",
        "${reference_fasta_shifted}.pac",
        "${reference_fasta_shifted}.sa",
        "${reference_fasta_shifted}.fai",
        sub(reference_fasta_shifted, ".fa$", ".dict")
    ]

    Array[Object] samples = read_objects(sample_sheet)
    Array[Object] target_regions = read_objects(target_region_list)

    # ----------------------------------------------------------------------------
    # check target regions
    # ----------------------------------------------------------------------------

    call gpc.get_contigs_from_interval_list as step0001_get_contig_id { input:
        interval_list = "${reference_fasta_original}.picard.mitochondria.interval_list"
    }

    # ----------------------------------------------------------------------------
    # process each sample
    # ----------------------------------------------------------------------------

    scatter (sample in samples) {

        # ------------------------------------------------------------------------
        # extract reads
        # ------------------------------------------------------------------------

        call gpc.extract_reads_from_bam as step1001_bam2fastq { input:
            bam = "${sample_bam_root}/${sample.id}.base.bam",
            bam_index = "${sample_bam_root}/${sample.id}.base.bam.bai",
            contigs = step0001_get_contig_id.contigs,
            output_prefix = "${sample.id}.mitochondria"
        }

        # ------------------------------------------------------------------------
        # mapping & variant call (original)
        # ------------------------------------------------------------------------

        call fastq2bam.fastq2bam as step2001_fastq2bam_original { input:
            reference_fasta = reference_fasta_original,
            reference_fasta_indexes = reference_fasta_original_indexes,
            sample_id = sample.id,
            sample_read_pairs = step1001_bam2fastq.read_pairs,
            bam__name = "${sample.id}.mitochondria_original.bam"
        }


        call bam2gvcf.bam2gvcf as step2002_bam2gvcf_original { input:
            reference_fasta = reference_fasta_original,
            reference_fasta_indexes = reference_fasta_original_indexes,
            bam = step2001_fastq2bam_original.bam,
            bam_index = step2001_fastq2bam_original.bam_index,
            sample_id = sample.id,
            sample_sex = sample.sex,
            regions = target_regions,
            output_prefix = "${sample.id}.mitochondria_original"
        }

        # ------------------------------------------------------------------------
        # mapping & variant call (shifted)
        # ------------------------------------------------------------------------

        call fastq2bam.fastq2bam as step2101_fastq2bam_shifted { input:
            reference_fasta = reference_fasta_shifted,
            reference_fasta_indexes = reference_fasta_shifted_indexes,
            sample_id = sample.id,
            sample_read_pairs = step1001_bam2fastq.read_pairs,
            bam__name = "${sample.id}.mitochondria_shifted.bam"
        }

        call bam2gvcf.bam2gvcf as step2102_bam2gvcf_shifted { input:
            reference_fasta = reference_fasta_shifted,
            reference_fasta_indexes = reference_fasta_shifted_indexes,
            bam = step2101_fastq2bam_shifted.bam,
            bam_index = step2101_fastq2bam_shifted.bam_index,
            sample_id = sample.id,
            sample_sex = sample.sex,
            regions = target_regions,
            output_prefix = "${sample.id}.mitochondria_shifted"
        }

    }

    # ----------------------------------------------------------------------------
    # output
    # ----------------------------------------------------------------------------

    output {
        Array[Array[File]] reads = step1001_bam2fastq.reads

        Array[Array[File]] original_gvcfs = step2002_bam2gvcf_original.gvcfs
        Array[Array[File]] original_gvcf_indexes = step2002_bam2gvcf_original.gvcf_indexes

        Array[Array[File]] shifted_gvcfs = step2102_bam2gvcf_shifted.gvcfs
        Array[Array[File]] shifted_gvcf_indexes = step2102_bam2gvcf_shifted.gvcf_indexes
    }

}
