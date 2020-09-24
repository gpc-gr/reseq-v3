#
#
#

version 1.0

import "../tools/gpc.wdl"


workflow bam2fastq {

    input {
        String id
        File bam
        File bam_index
        Array[String] contigs
        String output_prefix
    }

    call gpc.extract_reads_from_bam as step0001_extract_reads_from_bam { input:
        bam = bam,
        bam_index = bam_index,
        contigs = contigs,
        output_prefix = output_prefix
    }

    output {
        Array[File] reads = step0001_extract_reads_from_bam.reads
        Array[Object] read_pairs = read_objects(step0002_create_read_pair_sheet.read_pair_sheet)
    }

}
