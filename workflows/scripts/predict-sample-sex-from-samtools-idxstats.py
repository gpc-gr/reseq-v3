#!/usr/bin/env python3
#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

import argparse
import os
import re


def main():
    #
    parser = argparse.ArgumentParser()
    parser.add_argument('--male-expression')
    parser.add_argument('--female-expression')
    parser.add_argument('sources', nargs='+')
    args = parser.parse_args()

    check_male = compile(f'lambda x, y: {args.male_expression}') if args.male_expression else None
    check_female = compile(f'lambda x, y: {args.female_expression}') if args.female_expression else None

    #
    print('id\tchrX_ratio\tchrY_ratio\tpredicted_sex')

    for path in args.sources:
        id = os.path.basename(path).split('.')[0]
        chrX_ratio, chrY_ratio = _get_chrXY_read_ratio_from_samtools_idxstats(path)

        predicted_sex = 0
        if check_male and check_female:
            is_male = check_male(chrX_ratio, chrY_ratio)
            is_female = check_female(chrX_ratio, chrY_ratio)
            predicted_sex = {
                (True, False): 1,
                (False, True): 2,
                (False, False): 0,
                (True, True): 0
            }[is_male, is_female]

        print('{}\t{:.04f}\t{:.04f}\t{}'.format(id, chrX_ratio, chrY_ratio, predicted_sex))


def _get_chrXY_read_ratio_from_samtools_idxstats(path):
    #
    num_reads = 0
    num_reads_on_chrX = None
    num_reads_on_chrY = None

    with open(path) as fin:
        for line in fin:
            contig, _, mapped, unmapped = line.strip().split()

            if contig != '*':
                num_reads += int(mapped)

            if re.match('(chr)?X', contig):
                num_reads_on_chrX = int(mapped)
            elif re.match('(chr)?Y', contig):
                num_reads_on_chrY = int(mapped)

    #
    assert num_reads > 0
    assert num_reads_on_chrX is not None
    assert num_reads_on_chrY is not None

    return num_reads_on_chrX / num_reads, num_reads_on_chrY / num_reads


if __name__ == '__main__':
    main()
