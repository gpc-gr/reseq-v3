#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0

import "../tools/bwa.wdl"
import "../tools/picard.wdl"


workflow fastq2bam {

    # ----------------------------------------------------------------------------
    # input
    # ----------------------------------------------------------------------------

    input {
        File reference_fasta
        Array[File] reference_fasta_indexes
        String sample_id
        Array[Object] sample_read_pairs
        String bam__name
    }

    # ----------------------------------------------------------------------------
    # align, rmdup, BQSR
    # ----------------------------------------------------------------------------

    scatter (pair in sample_read_pairs) {

        call bwa.mem as step0001_align { input:
            reference_fasta = reference_fasta,
            reference_fasta_indexes = reference_fasta_indexes,
            read_group_header = "@RG\\tID:${pair.id}\\tPL:illumina\\tPU:${pair.id}\\tLB:${sample_id}\\tSM:${sample_id}",
            read1 = pair.read1,
            read2 = pair.read2,
            bam__name = "${pair.id}.bam"
        }

    }

    call picard.mark_duplicates as step0002_rmdup { input:
        source_bams = step0001_align.bam,
        rmdup_bam__name = bam__name,
        rmdup_metrics__name = "${bam__name}.picard.rmdup_metrics"
    }

    # ----------------------------------------------------------------------------
    # output
    # ----------------------------------------------------------------------------

    output {
        File bam = step0002_rmdup.rmdup_bam
        File bam_index = step0002_rmdup.rmdup_bam_index
        File picard_rmdup_metrics = step0002_rmdup.rmdup_metrics
    }

}
