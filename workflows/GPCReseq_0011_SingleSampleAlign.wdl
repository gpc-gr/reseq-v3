#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0

import "./modules/bamstats.wdl"
import "./modules/bqsr.wdl"
import "./modules/fastq2bam.wdl"
import "./modules/fastqstats.wdl"
import "./tools/gpc.wdl"
import "./tools/multiqc.wdl"


workflow GPCReseq_0011_SingleSampleAlign {

    # ----------------------------------------------------------------------------
    # input
    # ----------------------------------------------------------------------------

    input {
        String batch_id
        File reference_fasta
        File sample_sheet

        String? sex_prediction_male_expression
        String? sex_prediction_female_expression

        Array[String] bqsr_known_site_vcfs = []
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
    # process each sample
    # ----------------------------------------------------------------------------

    call gpc.get_contigs_from_interval_list as step0001_get_bqsr_target_contigs { input:
        interval_list = "${reference_fasta}.picard.autosome.interval_list"
    }

    scatter (sample in samples) {

        call gpc.parse_sample_read_specification as step1001_parse_sample_read_specification { input:
            source = sample.reads
        }

        scatter (fastq in step1001_parse_sample_read_specification.reads) {
            call fastqstats.fastqstats as step1001_fastqstats { input:
                fastq = fastq
            }
        }

        call fastq2bam.fastq2bam as step1002_fastq2bam { input:
            reference_fasta = reference_fasta,
            reference_fasta_indexes = reference_fasta_indexes,
            sample_id = sample.id,
            sample_read_pairs = step1001_parse_sample_read_specification.read_pairs,
            bam__name = "${sample.id}.base.bam"
        }

        call bamstats.bamstats as step1003_bamstats { input:
            reference_fasta = reference_fasta,
            reference_fasta_indexes = reference_fasta_indexes,
            bam = step1002_fastq2bam.bam,
            bam_index = step1002_fastq2bam.bam_index,
            output_prefix = "${sample.id}.base.bam"
        }

        if (length(bqsr_known_site_vcfs) > 0) {
            call bqsr.bqsr as step1004_bqsr { input:
                reference_fasta = reference_fasta,
                reference_fasta_indexes = reference_fasta_indexes,
                bam = step1002_fastq2bam.bam,
                bam_index = step1002_fastq2bam.bam_index,
                contigs = step0001_get_bqsr_target_contigs.contigs,
                known_site_vcfs = bqsr_known_site_vcfs,
                table__name = "${sample.id}.base.bam.bqsr.table"
            }
        }

    }

    # ----------------------------------------------------------------------------
    # compute batch metrics
    # ----------------------------------------------------------------------------

    Array[Pair[String, Array[File]]] multiqc_targets = [
        ("samtools.idxstats",                           step1003_bamstats.samtools_idxstats),
        ("picard.alignment_summary",                    step1003_bamstats.picard_alignment_summary),
        ("picard.picard_insert_size",                   step1003_bamstats.picard_insert_size),
        ("picard.picard_base_distribution_by_cycle",    step1003_bamstats.picard_base_distribution_by_cycle),
        ("picard.picard_gc_bias_detail",                step1003_bamstats.picard_gc_bias_detail),
        ("picard.picard_wgs_metrics_autosome",          select_all(step1003_bamstats.picard_wgs_metrics_autosome)),
        ("picard.picard_wgs_metrics_chrX",              select_all(step1003_bamstats.picard_wgs_metrics_chrX)),
        ("picard.picard_wgs_metrics_chrY",              select_all(step1003_bamstats.picard_wgs_metrics_chrY)),
        ("picard.picard_wgs_metrics_mitochondria",      select_all(step1003_bamstats.picard_wgs_metrics_mitochondria))
    ]

    scatter (entry in multiqc_targets) {

        call multiqc.report as step2001_multiqc { input:
            sources = entry.right,
            output_prefix = "${batch_id}.multiqc.${entry.left}"
        }

    }

    # ----------------------------------------------------------------------------
    # sex prediction
    # ----------------------------------------------------------------------------

    call gpc.predict_sample_sex_from_samtools_idxstats as step3001_predict_sample_sex { input:
        sources = step1003_bamstats.samtools_idxstats,
        male_expression = sex_prediction_male_expression,
        female_expression = sex_prediction_female_expression,
        output_prefix = "${batch_id}.samtools.idxstats.sex_prediction",
    }

    call gpc.fill_sex_into_sample_sheet_from_prediction_result as step3002_update_sample_sheet { input:
        original_sample_sheet = sample_sheet,
        sex_prediction_result = step3001_predict_sample_sex.prediction_result,
        updated_sample_sheet__name = "${batch_id}.samples.tsv"
    }

    # ----------------------------------------------------------------------------
    # output
    # ----------------------------------------------------------------------------

    output {
        # sample
        Array[Array[File]] sample_read_fastqc_zips = step1001_fastqstats.fastqc_zip

        Array[File] sample_bams = step1002_fastq2bam.bam
        Array[File] sample_bam_indexes = step1002_fastq2bam.bam_index
        Array[File] sample_picard_rmdup_metrics = step1002_fastq2bam.picard_rmdup_metrics
        Array[File] sample_bam_bqsr_tables = select_all(step1004_bqsr.table)

        Array[File] sample_samtools_idxstats = step1003_bamstats.samtools_idxstats

        Array[File] sample_picard_alignment_summary = step1003_bamstats.picard_alignment_summary
        Array[File] sample_picard_insert_size = step1003_bamstats.picard_insert_size
        Array[File] sample_picard_quality_distribution = step1003_bamstats.picard_quality_distribution
        Array[File] sample_picard_quality_by_cycle = step1003_bamstats.picard_quality_by_cycle
        Array[File] sample_picard_base_distribution_by_cycle = step1003_bamstats.picard_base_distribution_by_cycle
        Array[File] sample_picard_gc_bias_summary = step1003_bamstats.picard_gc_bias_summary
        Array[File] sample_picard_gc_bias_detail = step1003_bamstats.picard_gc_bias_detail
        Array[File] sample_picard_bait_bias_summary = step1003_bamstats.picard_bait_bias_summary
        Array[File] sample_picard_bait_bias_detail = step1003_bamstats.picard_bait_bias_detail
        Array[File] sample_picard_pre_adapter_summary = step1003_bamstats.picard_pre_adapter_summary
        Array[File] sample_picard_pre_adapter_detail = step1003_bamstats.picard_pre_adapter_detail

        Array[File] sample_picard_wgs_metrics_autosome = select_all(step1003_bamstats.picard_wgs_metrics_autosome)
        Array[File] sample_picard_wgs_metrics_chrX = select_all(step1003_bamstats.picard_wgs_metrics_chrX)
        Array[File] sample_picard_wgs_metrics_chrY = select_all(step1003_bamstats.picard_wgs_metrics_chrY)
        Array[File] sample_picard_wgs_metrics_mitochondria = select_all(step1003_bamstats.picard_wgs_metrics_mitochondria)

        # batch metrics
        Array[File] batch_multiqc_htmls = step2001_multiqc.html
        Array[File] batch_multiqc_zips = step2001_multiqc.zip

        # sex prediction
        File batch_sex_prediction_result = step3001_predict_sample_sex.prediction_result
        File batch_sex_prediction_read_ratio_plot = step3001_predict_sample_sex.read_ratio_plot

        File batch_updated_sample_sheet = step3002_update_sample_sheet.updated_sample_sheet
    }

}
