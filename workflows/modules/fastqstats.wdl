#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

version 1.0

import "../tools/fastqc.wdl"


workflow fastqstats {

    # ----------------------------------------------------------------------------
    # input
    # ----------------------------------------------------------------------------

    input {
        File fastq
    }

    # ----------------------------------------------------------------------------
    # fastqc
    # ----------------------------------------------------------------------------

    call fastqc.report as step0001_fastqc { input:
        fastq = fastq
    }

    # ----------------------------------------------------------------------------
    # output
    # ----------------------------------------------------------------------------

    output {
        File fastqc_zip = step0001_fastqc.zip
    }

}
