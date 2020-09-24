#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0

import "../tools/gatk3.wdl"
import "../tools/gpc.wdl"


workflow bqsr {

    # ----------------------------------------------------------------------------
    # input
    # ----------------------------------------------------------------------------

    input {
        File reference_fasta
        Array[File] reference_fasta_indexes
        File bam
        File bam_index
        Array[String] contigs
        Array[String] known_site_vcfs
        String table__name
    }

    # ----------------------------------------------------------------------------
    # BQSR
    # ----------------------------------------------------------------------------

    scatter (contig in contigs) {
        call gatk3.base_recalibrator as step0001_base_recalibrator { input:
            reference_fasta = reference_fasta,
            reference_fasta_indexes = reference_fasta_indexes,
            bam = bam,
            bam_index = bam_index,
            interval = contig,
            known_site_vcfs = known_site_vcfs,
            table__name = sub(table__name, ".table$", "${contig}.table")
        }
    }

    call gatk3.gather_bqsr_reports as step0002_merge_bqsr_table { input:
        sources = step0001_base_recalibrator.table,
        result__name = table__name
    }

    # ----------------------------------------------------------------------------
    # output
    # ----------------------------------------------------------------------------

    output {
        File table = step0002_merge_bqsr_table.result
    }

}
