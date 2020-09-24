#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0


task report {
    input {
        Array[File] sources
        String output_prefix
    }

    runtime {
        cpu: 1
        memory: "8G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        multiqc\
            --filename ~{output_prefix}.html\
            ~{sep=" " sources}

        mv ~{output_prefix}_data ~{output_prefix}.d
        zip -r ~{output_prefix}.d.zip ~{output_prefix}.d
    >>>

    output {
        File html = "${output_prefix}.html"
        File zip = "${output_prefix}.d.zip"
    }
}
