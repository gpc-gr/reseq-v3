#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0

import "../tools/bwa.wdl"
import "../tools/gpc.wdl"
import "../tools/samtools.wdl"


workflow fastaindex {

    input {
        File fasta
    }

    call bwa.index as step0001_bwa_index { input:
        fasta = fasta
    }

    call samtools.faidx as step0002_samtools_faidx { input:
        fasta = fasta
    }

    call samtools.dict as step0003_samtools_dict { input:
        fasta = fasta
    }

    scatter (type in ["autosome", "chrX", "chrY", "mitochondria"]) {
        call gpc.create_interval_list_from_sequence_dict as step0004_create_interval_list { input:
            dict = step0003_samtools_dict.fasta_dict,
            type = type,
            interval_list__name = "${basename(fasta)}.picard.${type}.interval_list"
        }
    }

    output {
        Array[File] bwa_indexes = step0001_bwa_index.bwa_indexes
        File fai = step0002_samtools_faidx.fasta_fai
        File dict = step0003_samtools_dict.fasta_dict
        Array[File] interval_lists = step0004_create_interval_list.interval_list
    }

}
