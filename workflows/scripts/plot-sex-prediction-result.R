#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

library(argparse)
library(ggplot2)
library(ggrepel)


parser <- ArgumentParser()
parser$add_argument('tsv')
parser$add_argument('pdf')
args <- parser$parse_args()


d <- read.table(args$tsv, head=T, sep='\t')
d$label <- d$id
if (nrow(d[d$predicted_sex > 0,]) > 0) {
    d[d$predicted_sex]$label <- ''
}
print(head(d))


pdf(args$pdf)
plot(ggplot(d, aes(x=chrX_ratio, y=chrY_ratio, colour=predicted_sex, label=label)) +
    geom_point() +
    geom_text_repel() +

    ggtitle('Ratio of reads mapped onto chrX/chrY') +
    xlab('Ratio of reads mapped onto chrX') +
    ylab('Ratio of reads mapped onto chrY')
)

dev.off()
