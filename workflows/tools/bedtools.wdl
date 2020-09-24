#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0


task maskfasta {
    input {
        File fasta
        File bed
        String masked_fasta__name
    }

    runtime {
        cpu: 1
        memory: "4G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        bedtools maskfasta -fi ~{fasta} -bed ~{bed} -fo ~{masked_fasta__name}
    >>>

    output {
        File masked_fasta = "${masked_fasta__name}"
    }
}
