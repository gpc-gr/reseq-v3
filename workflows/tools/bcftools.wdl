#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0


task annotate {
    input {
        File source
        File source_index
        String? id
        String? remove
        String output_type
        String result__name

        String index_type = if (output_type == "z") then "tbi" else "csi"

        Int threads = 4
    }

    command <<<
        bcftools view\
            --no-version\
            --threads ${WF_THREADS:-1}\
            ~{"--set-id " + id}\
            ~{"--remove " + remove}\
            --output-type ~{output_type}\
            --output ~{result__name}

        bcftools index\
            --threads ${WF_THREADS:-1}\
            --~{index_type}\
            ~{result__name}
    >>>

    output {
        File result = "${result__name}"
        File result_index = "${result__name}.${index_type}"
    }
}


task merge {
    input {
        Array[File] sources
        Array[File] source_indexes
        String output_type
        String result__name

        String index_type = if (output_type == "z") then "tbi" else "csi"
        Int threads = 4
    }

    command <<<
        bcftools merge\
            --no-version\
            --threads ${WF_THREADS:-1}\
            --file-list ~{write_lines(sources)}\
            --output-type ~{output_type}\
            --output ~{result__name}

        bcftools index\
            --threads ${WF_THREADS:-1}\
            --~{index_type}\
            ~{result__name}
    >>>

    output {
        File result = "${result__name}"
        File result_index = "${result__name}.${index_type}"
    }

}
