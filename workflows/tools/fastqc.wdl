#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0


task report {
    input {
        File fastq
    }

    runtime {
        cpu: 4
        memory: "1G"    # [recommendation] 250mb per thread
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        fastqc --threads ${NSLOTS:-1} --nogroup --outdir . ~{fastq}
    >>>

    output {
        # File zip = sub(basename(fastq), ".fastq*$", "_fastqc.zip")
        File zip = glob("*.zip")[0]
    }
}
