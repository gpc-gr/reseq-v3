#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0


task apply_recalibration {
    input {
        File reference_fasta
        Array[File] reference_fasta_indexes
        File vcf
        File vcf_index
        File snv_recal
        File snv_tranches
        File indel_recal
        File indel_tranches
        String snv_filter_level
        String indel_filter_level
        String result_vcf__name
    }

    command <<<
        JAVA_XMX_MB=$(echo '
            import os
            wf_memory_gb = float(os.environ.get("WF_MEMORY_GB", 1))
            java_xmx_mb = max(1000, wf_memory_gb * 1000 * 0.8)
            print(int(java_xmx_mb))
        ' | python -c 'import sys, textwrap; exec(textwrap.dedent(sys.stdin.read()).strip())')

        gatk -Xmx${JAVA_XMX_MB}m\
            --analysis_type ApplyRecalibration\
            --num_threads ${WF_THREADS:-1}\
            --input ~{vcf}\
            --recal_file ~{snv_recal}\
            --tranches_file ~{snv_tranches}\
            --ts_filter_level ~{snv_filter_level}\
            --mode SNP\
            --out ~{result_vcf__name}.snv_only.vcf.gz

        gatk -Xmx${JAVA_XMX_MB}m\
            --analysis_type ApplyRecalibration\
            --num_threads ${WF_THREADS:-1}\
            --input ~{result_vcf__name}.snv_only.vcf.gz\
            --recal_file ~{indel_recal}\
            --tranches_file ~{indel_tranches}\
            --ts_filter_level ~{indel_filter_level}\
            --mode SNP\
            --out ~{result_vcf__name}

        rm ~{result_vcf__name}.snv_only.vcf.gz
    >>>

    output {
        File result_vcf = "${result_vcf__name}"
        File result_vcf_index = "${result_vcf__name}.tbi"
    }
}


task base_recalibrator {
    input {
        File reference_fasta
        Array[File] reference_fasta_indexes
        File bam
        File bam_index
        String interval
        Array[String] known_site_vcfs = []
        String table__name

        Int threads = 1
        Float memory_gb = 8
    }

    runtime {
        cpu: threads
        memory: "${memory_gb}G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        JAVA_XMX_MB=$(echo '
            import os
            wf_memory_gb = float(os.environ.get("WF_MEMORY_GB", 1))
            java_xmx_mb = max(1000, wf_memory_gb * 1000 * 0.8)
            print(int(java_xmx_mb))
        ' | python -c 'import sys, textwrap; exec(textwrap.dedent(sys.stdin.read()).strip())')

        gatk -Xmx${JAVA_XMX_MB}m\
            --analysis_type BaseRecalibrator\
            --num_cpu_threads_per_data_thread ${WF_THREADS:-1}\
            --reference_sequence ~{reference_fasta}\
            --input_file ~{bam}\
            ~{sep=" " prefix("--knownSites ", known_site_vcfs)}\
            --intervals ~{interval}\
            --out ~{table__name}
    >>>

    output {
        File table = "${table__name}"
    }
}


task combine_gvcfs {
    input {
        File reference_fasta
        Array[File] reference_fasta_indexes
        Array[File] gvcfs
        Array[File] gvcf_indexes
        Int size
        Int index
        String? region
        Int? interval_padding
        String combined_gvcf__name
    }

    command <<<
        #
        start=$(expr $(expr '~{size}' '*' '~{index}') + 1)
        end=$(expr ${start} '+' '~{size}')

        cat ~{write_lines(gvcfs)}\
            | awk -v start=${start} -v end=${end} 'start <= NR && NR < end'\
            > targets.txt

        #
        gatk\
            --analysis_type CombineGVCFs\
            --reference_sequence ~{reference_fasta}\
            $(cat targets.txt | awk '{ print " --variant " $0 }')\
            ~{"--intervals " + region}\
            ~{"--interval_padding " + interval_padding}\
            --out ~{combined_gvcf__name}
    >>>

    output {
        File combined_gvcf = "${combined_gvcf__name}"
        File combined_gvcf_index = "${combined_gvcf__name}.tbi"
    }
}


task gather_bqsr_reports {
    input {
        Array[File] sources
        String result__name
    }

    runtime {
        cpu: 1
        memory: "1G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        java -Xmx800m -cp /opt/conda/opt/gatk-3.7/GenomeAnalysisTK.jar org.broadinstitute.gatk.tools.GatherBqsrReports\
            ~{sep=" " prefix("INPUT=", sources)}\
            OUTPUT=~{result__name}
    >>>

    output {
        File result = "${result__name}"
    }
}


task haplotype_caller_gvcf {
    input {
        File reference_fasta
        Array[File] reference_fasta_indexes
        File bam
        File bam_index
        File? bqsr_table
        String interval
        Int ploidy
        String gvcf__name

        Int threads = 1
        Float memory_gb = 8
    }

    runtime {
        cpu: threads
        memory: "${memory_gb}G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        JAVA_XMX_MB=$(echo '
            import os
            wf_memory_gb = float(os.environ.get("WF_MEMORY_GB", 1))
            java_xmx_mb = max(1000, wf_memory_gb * 1000 * 0.8)
            print(int(java_xmx_mb))
        ' | python -c 'import sys, textwrap; exec(textwrap.dedent(sys.stdin.read()).strip())')

        gatk -Xmx${JAVA_XMX_MB}m\
            --analysis_type HaplotypeCaller\
            --num_cpu_threads_per_data_thread ${WF_THREADS:-1}\
            --reference_sequence ~{reference_fasta}\
            --input_file ~{bam}\
            ~{"--BQSR " + bqsr_table}\
            --intervals ~{interval}\
            --sample_ploidy ~{ploidy}\
            --emitRefConfidence GVCF\
            --out ~{gvcf__name}
    >>>

    output {
        File gvcf = "${gvcf__name}"
        File gvcf_index = "${gvcf__name}.tbi"
    }
}


task genotype_gvcfs {
    input {
        File reference_fasta
        Array[File] reference_fasta_indexes
        Array[File] gvcfs
        Array[File] gvcf_indexes
        String region
        Int? interval_padding
        String vcf__name
    }

    command <<<
        gatk\
            --analysis_type GenotypeGVCFs\
            --reference_sequence ~{reference_fasta}\
            ~{sep=" " prefix("--variant ", gvcfs)}\
            --intervals ~{region}\
            ~{"--interval_padding " + interval_padding}\
            --out ~{vcf__name}
    >>>

    output {
        File vcf = "${vcf__name}"
        File vcf_index = "${vcf__name}.tbi"
    }
}


task variant_recalibrator {
    input {
        File reference_fasta
        Array[File] reference_fasta_indexes
        Array[File] vcfs
        Array[File] vcf_indexes
        Array[String] tranches
        Array[String] annotations
        Array[String] resources
        Int max_gaussians
        String mode
        String output_prefix

        Int threads = 1
        Float memory_gb = 8
    }

    runtime {
        cpu: threads
        memory: "${memory_gb}G"
        simg: "gpc-gr/reseq:v3"
    }

    command <<<
        JAVA_XMX_MB=$(echo '
            import os
            wf_memory_gb = float(os.environ.get("WF_MEMORY_GB", 1))
            java_xmx_mb = max(1000, wf_memory_gb * 1000 * 0.8)
            print(int(java_xmx_mb))
        ' | python -c 'import sys, textwrap; exec(textwrap.dedent(sys.stdin.read()).strip())')

        gatk -Xmx${JAVA_XMX_MB}\
            --analysis_type VariantRecalibrator\
            --num_threads ${WF_THREADS:-1}\
            ~{sep=" " prefix("--input ", vcfs)}\
            --recal_file ~{output_prefix}.recal\
            --tranches_file ~{output_prefix}.tranches\
            --TStranche ~{sep=" --TStranche " tranches}\
            ~{sep=" " prefix("--use_annotation ", annotations)}\
            ~{sep=" " prefix("--resource ", resources)}\
            --maxGaussians ~{max_gaussians}\
            --mode ~{mode}\
            --rscript_file ~{output_prefix}.rscript
    >>>

    output {
        File recal = "${output_prefix}.recal"
        File tranches = "${output_prefix}.tranches"
        File rscript = "${output_prefix}.rscript"
    }
}
