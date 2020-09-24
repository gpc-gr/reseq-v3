#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0


task index {
    input {
        File fasta
    }

    runtime {
        cpu: 1
        memory: "32G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        if [ ! -e ~{basename(fasta)} ]; then
            ln -s ~{fasta} ~{basename(fasta)}
        fi

        bwa index ~{basename(fasta)}
    >>>

    output {
        Array[File] bwa_indexes = [
            "${basename(fasta)}.amb",
            "${basename(fasta)}.ann",
            "${basename(fasta)}.bwt",
            "${basename(fasta)}.pac",
            "${basename(fasta)}.sa"
        ]
    }
}


task mem {
    input {
        File reference_fasta
        Array[File] reference_fasta_indexes
        String read_group_header
        File read1
        File? read2
        String bam__name

        Int threads = 4
        Float? memory_gb = 8
    }

    runtime {
        cpu: threads
        memory: "${memory_gb}G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        #
        BWA_THREADS=$(echo '
            import os
            wf_threads = int(os.environ.get("WF_THREADS", 1))
            bwa_threads = max(1, int(wf_threads * (20.0 / 24.0)))
            print(bwa_threads)
        ' | python -c 'import sys, textwrap; exec(textwrap.dedent(sys.stdin.read()).strip())')
        SAMTOOLS_THREADS = $(echo '
            import os
            wf_threads = int(os.environ.get("WF_THREADS", 1))
            samtools_threads = max(1, int(wf_threads * (4.0 / 24.0)))
            print(samtools_threads)
        ' | python -c 'import sys, textwrap; exec(textwrap.dedent(sys.stdin.read()).strip())')

        #
        bwa mem\
            -t ${BWA_THREADS:-1}\
            -K 10000000\
            ~{if (!defined(read2)) then "-p" else ""}\
            ~{"-R '" + read_group_header + "'"}\
            ~{reference_fasta}\
            ~{read1}\
            ~{read2}\
        | samtools sort\
            --threads ${SAMTOOLS_THREADS:-1}\
            --output-fmt BAM\
            -l 1\
            -o ~{bam__name}
    >>>

    output {
        File bam = "${bam__name}"
    }
}
