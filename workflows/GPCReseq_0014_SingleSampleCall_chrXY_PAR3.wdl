#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0

import "./modules/bam2gvcf.wdl"
import "./modules/fastq2bam.wdl"
import "./tools/gpc.wdl"


workflow GPCReseq_0014_SingleSampleCall_chrXY_PAR3 {

    # ----------------------------------------------------------------------------
    # input
    # ----------------------------------------------------------------------------

    input {
        String batch_id
        File reference_fasta
        File sample_sheet
        String sample_bam_root

        Boolean apply_bqsr = false
        File target_region_list = "${reference_fasta}.regions.chrXY_PAR3.tsv"
    }

    Array[File] reference_fasta_indexes = [
        "${reference_fasta}.amb",       # bwa
        "${reference_fasta}.ann",
        "${reference_fasta}.bwt",
        "${reference_fasta}.pac",
        "${reference_fasta}.sa",
        "${reference_fasta}.fai",       # general
        sub(reference_fasta, ".fa$", ".dict")
    ]

    Array[Object] samples = read_objects(sample_sheet)

    # ----------------------------------------------------------------------------
    # check target regions
    # ----------------------------------------------------------------------------

    call gpc.get_contigs_from_interval_list as step0001_get_chrX_contig_id { input:
        interval_list = "${reference_fasta}.picard.chrX.interval_list"
    }

    call gpc.filter_genome_region_list_by_contig as step0002_resolve_chrX_regions { input:
        source = target_region_list,
        contig = step0001_get_chrX_contig_id.contigs[0]
    }

    call gpc.get_contigs_from_interval_list as step0003_get_chrY_contig_id { input:
        interval_list = "${reference_fasta}.picard.chrY.interval_list"
    }

    call gpc.filter_genome_region_list_by_contig as step0004_resolve_chrY_regions { input:
        source = target_region_list,
        contig = step0003_get_chrY_contig_id.contigs[0]
    }

    # ----------------------------------------------------------------------------
    # process each sample
    # ----------------------------------------------------------------------------

    scatter (sample in samples) {
        if (sample.sex == "1" || sample.sex == "2") {

            # --------------------------------------------------------------------
            # mapping
            # --------------------------------------------------------------------

            call gpc.extract_reads_from_bam as step1001_bam2fastq { input:
                bam = "${sample_bam_root}/${sample.id}.base.bam",
                bam_index = "${sample_bam_root}/${sample.id}.base.bam.bai",
                contigs = [
                    step0001_get_chrX_contig_id.contigs[0],
                    step0003_get_chrY_contig_id.contigs[0]
                ],
                output_prefix = "${sample.id}.chrXY_PAR3"
            }

            call fastq2bam.fastq2bam as step1002_fastq2bam { input:
                reference_fasta = reference_fasta,
                reference_fasta_indexes = reference_fasta_indexes,
                sample_id = sample.id,
                sample_read_pairs = step1001_bam2fastq.read_pairs,
                bam__name = "${sample.id}.chrXY_PAR3.bam"
            }

            # --------------------------------------------------------------------
            # call
            # --------------------------------------------------------------------

            call bam2gvcf.bam2gvcf as step2001_bam2gvcf_chrX { input:
                reference_fasta = reference_fasta,
                reference_fasta_indexes = reference_fasta_indexes,
                bam = step1002_fastq2bam.bam,
                bam_index = step1002_fastq2bam.bam_index,
                bqsr_table = if (apply_bqsr) then "${sample_bam_root}/${sample.id}.base.bam.bqsr.table" else "",
                sample_id = sample.id,
                sample_sex = sample.sex,
                regions = step0002_resolve_chrX_regions.regions,
                output_prefix = "${sample.id}.chrXY_PAR3"
            }

            if (sample.sex == "1") {
                call bam2gvcf.bam2gvcf as step2002_bam2gvcf_chrY { input:
                    reference_fasta = reference_fasta,
                    reference_fasta_indexes = reference_fasta_indexes,
                    bam = step1002_fastq2bam.bam,
                    bam_index = step1002_fastq2bam.bam_index,
                    bqsr_table = if (apply_bqsr) then "${sample_bam_root}/${sample.id}.base.bam.bqsr.table" else "",
                    sample_id = sample.id,
                    sample_sex = sample.sex,
                    regions = step0004_resolve_chrY_regions.regions,
                    output_prefix = "${sample.id}.chrXY_PAR3"
                }
            }

        }
    }

    # ----------------------------------------------------------------------------
    # input
    # ----------------------------------------------------------------------------

    output {
        Array[Array[File]] chrXY_reads = select_all(step1001_bam2fastq.reads)

        Array[File] chrXY_bams = select_all(step1002_fastq2bam.bam)
        Array[File] chrXY_bam_indexes = select_all(step1002_fastq2bam.bam_index)

        Array[Array[File]] chrX_gvcfs = select_all(step2001_bam2gvcf_chrX.gvcfs)
        Array[Array[File]] chrX_gvcf_indexes = select_all(step2001_bam2gvcf_chrX.gvcf_indexes)

        Array[Array[File]] chrY_gvcfs = select_all(step2002_bam2gvcf_chrY.gvcfs)
        Array[Array[File]] chrY_gvcf_indexes = select_all(step2002_bam2gvcf_chrY.gvcf_indexes)
    }

}
