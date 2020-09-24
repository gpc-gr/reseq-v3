#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0


task check_joint_genotyping_chunk_consistency {
    input {
        Array[File] chunk_vcfs
        Array[File] chunk_vcf_indexes
        String inconsistent_variant_table__name
    }

    command <<<
        /opt/gpc/reseq/workflows/scripts/check-joint-genotyping-chunk-consistency.py\
            ~{sep=" " chunk_vcfs}\
        > ~{inconsistent_variant_table__name}
    >>>

    output {
        File inconsistent_variant_table = "${inconsistent_variant_table__name}"
    }
}


task check_mitochondria_vcf_consistency {
    input {
        File original_vcf
        File original_vcf_index
        File shifted_vcf
        File shifted_vcf_index
        String inconsistent_variant_table__name
    }

    command <<<
        /opt/gpc/reseq/workflows/scripts/check-mitochondria-vcf-consistency.py\
            ~{original_vcf}\
            ~{shifted_vcf}\
        > ~{inconsistent_variant_table__name}
    >>>

    output {
        File inconsistent_variant_table = "${inconsistent_variant_table__name}"
    }
}


task concat_chunk_vcfs {
    input {
        Array[File] chunk_vcfs
        Array[File] chunk_vcf_indexes
        File inconsistent_variant_table
        String combined_vcf__name
    }

    command <<<
        /opt/gpc/reseq/workflows/scripts/concat-chunk-vcfs.py\
            --inconsistent-variant-table ~{inconsistent_variant_table}\
            --threads 4\
            ~{sep=" " chunk_vcfs}\
        | bcftools view\
            --no-version\
            --threads 4\
            --output-type z\
            --output-file ~{combined_vcf__name}

        bcftools index\
            --threads 8\
            --tbi\
            ~{combined_vcf__name}
    >>>

    output {
        File combined_vcf = "${combined_vcf__name}"
        File combined_vcf_index = "${combined_vcf__name}.tbi"
    }
}


task collect_sample_files {
    input {
        File sample_sheet
        String sample_file_root
        String sample_file_suffix
        String sample_file_index_extension
    }

    command <<<
        cat ~{sample_sheet}\
            | awk 'NR > 1 { print "~{sample_file_root}/" $1 "~{sample_file_suffix}" }'\
            > files.txt

        cat files.txt\
            | awk '{ print $0 "~{sample_file_index_extension}" }'\
            > file_indexes.txt
    >>>

    output {
        Array[File] files = read_lines("files.txt")
        Array[File] file_indexes = read_lines("file_indexes.txt")
    }
}


task convert_depth_statistics_tsv_to_wig {
    input {
        File tsv
        String type
        String wig__name
    }

    command <<<
        gzip\
            --decompress\
            --stdout\
            ~{tsv}\
        | /opt/gpc/reseq/workflows/scripts/convert-depth-statistics-tsv-to-wig.py\
            --type ~{type}\
        | gzip\
            --stdout\
        > ~{wig__name}
    >>>

    output {
        File wig = "${wig__name}"
    }
}


task copy_file {
    input {
        File original
    }

    runtime {
        cpu: 1
        memory: "1G"
        simg: "gpc-gr/reseq:v3"
        backend: "Local"
    }

    command {
        ln ${original} ${basename(original)}
    }

    output {
        File copied = "${basename(original)}"
    }
}


task copy_genome_region_files {
    input {
        String genome_build
        String output_prefix
    }

    runtime {
        cpu: 1
        memory: "1G"
        simg: "gpc-gr/reseq:v3"
        backend: "Local"
    }

    command <<<
        sp=/opt/gpc/reseq/workflows/data/genome/~{genome_build}/~{genome_build}
        op=~{output_prefix}

        cp ${sp}.regions.autosome.tsv ${op}.regions.autosome.tsv
        cp ${sp}.regions.chrXY_PAR2.tsv ${op}.regions.chrXY_PAR2.tsv
        cp ${sp}.regions.chrXY_PAR3.tsv ${op}.regions.chrXY_PAR3.tsv
        cp ${sp}.regions.mitochondria.tsv ${op}.regions.mitochondria.tsv
    >>>

    output {
        Array[File] region_files = [
            "${output_prefix}.regions.autosome.tsv",
            "${output_prefix}.regions.chrXY_PAR2.tsv",
            "${output_prefix}.regions.chrXY_PAR3.tsv",
            "${output_prefix}.regions.mitochondria.tsv"
        ]
    }
}


task create_allele_count_vcf {
    input {
        File source
        File source_index
        String result__name

        String ac_key = "AC"
        String an_key = "AN"
    }

    command <<<
        bcftools +fill-AN-AC\
            ~{source}\
        | /opt/gpc/reseq/workflows/scripts/rename-vcf-info-key.py\
            --mapping AC:~{ac_key}\
            --mapping AN:~{an_key}\
        | bcftools view\
            --no-version\
            --output-type z\
            --output-file ~{result__name}

        bcftools index\
            --tbi\
            ~{result__name}
    >>>

    output {
        File result = "${result__name}"
        File result = "${result__name}.tbi"
    }
}


task create_chrY_XTR_bed {
    input {
        String genome_build
    }

    runtime {
        cpu: 1
        memory: "1G"
        simg: "gpc-gr/reseq:v3"
        backend: "Local"
    }

    command <<<
        xsv search\
            --select name\
            chrY_XTR\
            /opt/gpc/reseq/workflows/data/genome/~{genome_build}/~{genome_build}.regions.chrXY_PAR3.tsv\
        | xsv select\
            --no-header\
            contig,start,end\
        | awk\
            -F','\
            '{ print $1 "\t" ($2 - 1) "\t" ($3 - 1) }'
    >>>

    output {
        File bed = stdout()
    }
}


task create_depth_bcf_from_bam {
    input {
        File bam
        File bam_index
        String contig
        Int start
        Int end
        Int mapq_threshold
        String bcf__name
    }

    runtime {
        cpu: 2
        memory: "1G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        samtools depth\
            -aa\
            -r ~{contig}:~{start}-~{end}\
            -Q ~{mapq_threshold}\
            ~{bam}\
        | /opt/gpc/reseq/workflows/scripts/create-depth-vcf-from-samtools-depth.py\
            --contig ~{contig}\
            --length ~{end}\
            --sample ~{basename(bam)}\
        | bcftools view\
            --no-version\
            --threads 2\
            --output-type b\
            --output-file ~{bcf__name}

        bcftools index\
            --threads 2\
            --csi\
            ~{bcf__name}
    >>>

    output {
        File bcf = "${bcf__name}"
        File bcf_index = "${bcf__name}.csi"
    }
}


task create_depth_statistics_tsv_from_depth_bcf {
    input {
        File bcf
        File bcf_index
        String tsv__name
    }

    command <<<
        bcftools view\
            --no-version\
            --threads 2\
            ~{bcf}\
        | /opt/gpc/reseq/workflows/scripts/create-depth-statistics-tsv-from-depth-vcf.py\
        | bgzip\
            --threads 4\
            --stdout\
        > ~{tsv__name}

        tabix\
            --sequence 1\
            --begin 2\
            --end 2\
            --skip-lines 1\
            ~{tsv__name}
    >>>

    output {
        File tsv = "${tsv__name}"
        File tsv_index = "${tsv__name}.tbi"
    }

}


task create_genotype_count_vcf {
    input {
        File source
        File source_index
        String result__name

        String key = "GenotypeCount"
    }

    command <<<
        bcftools view\
            --no-version\
            ~{source}\
        | /opt/gpc/reseq/workflows/scripts/create-genotype-count-vcf.py\
            --key ~{key}\
        | bcftools view\
            --no-version\
            --output-type z\
            --output-file ~{result__name}

        bcftools index\
            --tbi\
            ~{result__name}
    >>>

    output {
        File result = "${result__name}"
        File result = "${result__name}.tbi"
    }
}


task create_interval_list_from_sequence_dict {
    input {
        File dict
        String type
        String interval_list__name
    }

    runtime {
        cpu: 1
        memory: "1G"
        simg: "gpc-gr/reseq:v3"
        backend: "Local"
    }

    command <<<
        cat ~{dict}\
            | /opt/gpc/reseq/workflows/scripts/create-interval-list-from-sequence-dict.py --~{type}\
            > ~{interval_list__name}
    >>>

    output {
        File interval_list = "${interval_list__name}"
    }
}


task enumerate_joint_genotyping_chunks {
    input {
        Int start
        Int end
        Int size
    }

    command <<<
        /opt/gpc/reseq/workflows/scripts/enumerate-joint-genotyping-chunks.py\
            --start ~{start}\
            --end ~{end}\
            --size ~{size}
    >>>

    output {
        Array[Object] chunks = read_objects(stdout())
    }
}


task extract_reads_from_bam {
    input {
        File bam
        File bam_index
        Array[String] contigs
        String output_prefix
    }

    runtime {
        cpu: 4
        memory: "2G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        # ------------------------------------------------------------------------
        # extract reads from bam
        # ------------------------------------------------------------------------

        bam0=~{bam}
        bam1=$TMPDIR/$(basename $bam0).unmapped1.bam
        bam2=$TMPDIR/$(basename $bam0).unmapped2.bam
        bam3=$TMPDIR/$(basename $bam0).unmapped3.bam
        bam4=$TMPDIR/$(basename $bam0).mapped.bam

        samtools view --threads 6 -b -u -f  4 -F 264 -o $bam1 $bam0
        samtools view --threads 6 -b -u -f  8 -F 260 -o $bam2 $bam0
        samtools view --threads 6 -b -u -f 12 -F 256 -o $bam3 $bam0
        samtools view --threads 6 -b -u       -F 268 -o $bam4 $bam0 ~{sep=" " contigs}

        samtools merge\
            --threads 2\
            -\
            $bam1 $bam2 $bam3 $bam4\
        | samtools sort\
            --threads 2\
            -T $TMPDIR/$(basename $bam).sorting\
            -n\
            -\
        | picard -Xmx1G SamToFastq\
            INPUT=/dev/stdin\
            OUTPUT_PER_RG=true\
            OUTPUT_DIR=$(pwd)\
            INCLUDE_NON_PF_READS=true\
            VALIDATION_STRINGENCY=SILENT

        for path in *.fastq; do
            new_path=~{output_prefix}.${path}
            mv $path $new_path
            pigz --processes 6 ${new_path}
        done

        # ------------------------------------------------------------------------
        # create read pair sheet
        # ------------------------------------------------------------------------

        /opt/gpc/reseq/workflows/scripts/create-read-pair-sheet.py\
            ${output_prefix}\
        > ${output_prefix}.read_pairs.tsv
    >>>

    output {
        Array[File] reads = glob("${output_prefix}.*.fastq.gz")
        Array[Object] read_pairs = read_objects("${output_prefix}.read_pairs.tsv")
    }
}


task fill_sex_into_sample_sheet_from_prediction_result {
    input {
        File original_sample_sheet
        File sex_prediction_result
        String updated_sample_sheet__name
    }

    runtime {
        cpu: 1
        memory: "1G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        /opt/gpc/reseq/workflows/scripts/fill-sex-into-sample-sheet-from-prediction-result.py\
            ~{original_sample_sheet}\
            ~{sex_prediction_result}\
        > ~{updated_sample_sheet__name}
    >>>

    output {
        File updated_sample_sheet = "${updated_sample_sheet__name}"
    }
}


task filter_file_list_by_keyword {
    input {
        Array[File] sources
        String keyword
    }

    runtime {
        cpu: 1
        memory: "1G"
        simg: "gpc-gr/reseq:v3"
        backend: "Local"
    }

    command <<<
        cat ~{write_lines(sources)}\
            | fgrep '~{keyword}'\
            > matched.txt
    >>>

    output {
        Array[File] matches = read_lines("matched.txt")
    }
}


task filter_genome_region_list_by_contig {
    input {
        File source
        String contig
    }

    runtime {
        cpu: 1
        memory: "1G"
        simg: "gpc-gr/reseq:v3"
        backend: "Local"
    }

    command <<<
        cat ~{source} | awk 'NR == 1 || $2 == "~{contig}"'
    >>>

    output {
        Array[Object] regions = read_objects(stdout())
    }
}


task find_vcf_files_in_directory {
    input {
        String directory
    }

    command <<<
        find ~{directory} -name "*.vcf.gz" > vcfs.txt
        cat vcfs.txt | awk '{ print $0 ".tbi" }' > vcf_indexes.txt
    >>>

    output {
        Array[File] vcfs = read_lines("vcfs.txt")
        Array[File] vcf_indexes = read_lines("vcf_indexes.txt")
    }
}


task get_contigs_from_interval_list {
    input {
        File interval_list
    }

    runtime {
        cpu: 1
        memory: "1G"
        simg: "gpc-gr/reseq:v3"
        backend: "Local"
    }

    command <<<
        cat ~{interval_list} | grep -v @ | awk '{ print $1 }' | sort | uniq
    >>>

    output {
        Array[String] contigs = read_lines(stdout())
    }
}


task merge_vcf_annotations {
    input {
        File source
        File source_index
        Array[File] annotation_sources
        Array[String] annotation_config
        String output_type
        String result__name

        String index_type = if (output_type == "z") then "tbi" else "csi"
    }

    command <<<
        /opt/gpc/reseq/workflows/scripts/merge-vcf-annotations.py\
            --source ~{source}\
            --output ~{result__name}\
            --output-type ~{output_type}\
            --config ~{write_lines(annotation_config)}
    >>>

    output {
        File result = "${result__name}"
        File result_index = "${result__name}.${index_type}"
    }
}


task parse_sample_read_specification {
    input {
        String source
    }

    runtime {
        cpu: 1
        memory: "1G"
        simg: "gpc-gr/reseq:v3"
        backend: "Local"
    }

    command <<<
        echo -e 'id\tread1\tread2' > read_pairs.txt
        echo "~{source}" | tr ',' '\n' | tr ':' '\t' >> read_pairs.txt

        cat read_pairs.txt | awk 'NR > 1 { print $2 "\n" $3 }' > reads.txt
    >>>

    output {
        Array[Object] read_pairs = read_objects("read_pairs.txt")
        Array[File] reads = read_lines("reads.txt")
    }
}


task predict_sample_sex_from_samtools_idxstats {
    input {
        Array[File] sources
        String? male_expression
        String? female_expression
        String output_prefix
    }

    String male_option = if (defined(male_expression)) then "--male-expression '${male_expression}'" else ""
    String female_option = if (defined(female_expression)) then "--female-expression '${female_expression}'" else ""

    runtime {
        cpu: 1
        memory: "4G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        /opt/gpc/reseq/workflows/scripts/predict-sample-sex-from-samtools-idxstats.py\
            ~{male_option}\
            ~{female_option}\
            ~{sep=" " sources}\
        > ~{output_prefix}.tsv

        Rscript /opt/gpc/reseq/workflows/scripts/plot-sex-prediction-result.R\
            ~{output_prefix}.tsv\
            ~{output_prefix}.tsv.pdf
    >>>

    output {
        File prediction_result = "${output_prefix}.tsv"
        File read_ratio_plot = "${output_prefix}.tsv.pdf"
    }
}


task shift_back_mitochondria_vcf {
    input {
        String contig
        Int shift_size
        File shifted_vcf
        File shifted_vcf_index
        String shifted_back_vcf__name
    }

    command <<<
        bcftools view\
            --no-version\
            ~{shifted_vcf}\
        | /opt/gpc/reseq/workflows/scripts/shift-back-mitochondria-vcf.py\
            --contig ~{contig}\
            --shift-size ~{shift_size}\
        | bcftools sort\
            --output-type z\
            --output-file ~{shifted_back_vcf__name}

        bcftools index\
            --tbi\
            ~{shifted_back_vcf__name}
    >>>

    output {
        File shifted_back_vcf = "${shifted_back_vcf__name}"
        File shifted_back_vcf_index = "${shifted_back_vcf__name}.tbi"
    }
}


task shift_mitochondria_sequence {
    input {
        File fasta
        Int shift_size
        String shifted_fasta__name
    }

    runtime {
        cpu: 1
        memory: "4G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        cat\
            ~{fasta}\
        | /opt/gpc/reseq/workflows/scripts/shift-mitochondria-sequence.py\
            --shift-size ~{shift_size} \
        > ~{shifted_fasta__name}
    >>>

    output {
        File shifted_fasta = "${shifted_fasta__name}"
    }
}
