#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0

import "./modules/fastaindex.wdl"
import "./tools/bedtools.wdl"
import "./tools/gpc.wdl"


workflow GPCReseq_0001_ReferencePreparation {

    # ----------------------------------------------------------------------------
    # input
    # ----------------------------------------------------------------------------

    input {
        File fasta
        String genome_build

        Boolean process_chrXY_PAR3 = true
        Boolean process_mitochondria = true
    }

    # ----------------------------------------------------------------------------
    # base
    # ----------------------------------------------------------------------------

    call fastaindex.fastaindex as step0001_base_index { input:
        fasta = fasta
    }

    call gpc.copy_genome_region_files as step0002_base_copy_region_files { input:
        genome_build = genome_build,
        output_prefix = basename(fasta)
    }

    call gpc.copy_file as step0003_copy_original_file { input:
        original = fasta
    }

    # ----------------------------------------------------------------------------
    # chrXY_PAR3
    # ----------------------------------------------------------------------------

    if (defined(process_chrXY_PAR3) && process_chrXY_PAR3) {

        call gpc.create_chrY_XTR_bed as step1001_chrXY_PAR3_create_chrY_XTR_bed { input:
            genome_build = genome_build
        }

        call bedtools.maskfasta as step1002_chrXY_PAR3_mask_fasta { input:
            fasta = fasta,
            bed = step1001_chrXY_PAR3_create_chrY_XTR_bed.bed,
            masked_fasta__name = sub(basename(fasta), ".fa$", "") + ".chrXY_PAR3.fa"
        }

        # just to avoid the following error:
        #     WorkflowManagerActor Workflow * failed (during FinalizingWorkflowState)
        #     :java.nio.file.FileAlreadyExistsException: /path/to/${fasta}
        call fastaindex.fastaindex as step1003_chrXY_PAR3_index { input:
            fasta = step1002_chrXY_PAR3_mask_fasta.masked_fasta
        }

    }

    # ----------------------------------------------------------------------------
    # mitochondria
    # ----------------------------------------------------------------------------

    if (process_mitochondria) {

        call gpc.shift_mitochondria_sequence as step2001_mitochondria_shift_sequence { input:
            fasta = fasta,
            shift_size = 10000,
            shifted_fasta__name = sub(basename(fasta), ".fa$", "") + ".mitochondria_shifted.fa"
        }

        call fastaindex.fastaindex as step2002_mitochondria_index { input:
            fasta = step2001_mitochondria_shift_sequence.shifted_fasta
        }

    }

    # ----------------------------------------------------------------------------
    # output
    # ----------------------------------------------------------------------------

    output {
        File base_fasta = step0003_copy_original_file.copied
        Array[File] base_fasta_bwa_indexes = step0001_base_index.bwa_indexes
        File base_fasta_fai = step0001_base_index.fai
        File base_fasta_dict = step0001_base_index.dict
        Array[File] base_fasta_interval_lists = step0001_base_index.interval_lists
        Array[File] base_region_files = step0002_base_copy_region_files.region_files

        File? chrXY_PAR3_fasta = step1002_chrXY_PAR3_mask_fasta.masked_fasta
        Array[File]? chrXY_PAR3_fasta_bwa_indexes = step1003_chrXY_PAR3_index.bwa_indexes
        File? chrXY_PAR3_fasta_fai = step1003_chrXY_PAR3_index.fai
        File? chrXY_PAR3_fasta_dict = step1003_chrXY_PAR3_index.dict
        Array[File]? chrXY_PAR3_fasta_interval_lists = step1003_chrXY_PAR3_index.interval_lists

        File? mitochondria_fasta = step2001_mitochondria_shift_sequence.shifted_fasta
        Array[File]? mitochondria_fasta_bwa_indexes = step2002_mitochondria_index.bwa_indexes
        File? mitochondria_fasta_fai = step2002_mitochondria_index.fai
        File? mitochondria_fasta_dict = step2002_mitochondria_index.dict
        Array[File]? mitochondria_fasta_interval_lists = step2002_mitochondria_index.interval_lists
    }

}
