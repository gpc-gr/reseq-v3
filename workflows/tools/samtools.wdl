#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0


task dict {
    input {
        File fasta
    }

    runtime {
        cpu: 1
        memory: "4G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        samtools dict ~{fasta} > ~{sub(basename(fasta), ".fa$", ".dict")}
    >>>

    output {
        File fasta_dict = sub(basename(fasta), ".fa$", ".dict")
    }
}


task faidx {
    input {
        File fasta
    }

    runtime {
        cpu: 1
        memory: "4G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        if [ ! -e ~{basename(fasta)} ]; then
            ln -s ~{fasta} ~{basename(fasta)}
        fi

        samtools faidx ~{basename(fasta)}
    >>>

    output {
        File fasta_fai = "${basename(fasta)}.fai"
    }
}


task idxstats {
    input {
        File bam
        File bam_index
        String idxstats__name
    }

    runtime {
        cpu: 1
        memory: "4G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        samtools idxstats ~{bam} > ~{idxstats__name}
    >>>

    output {
        File idxstats = "${idxstats__name}"
    }
}
