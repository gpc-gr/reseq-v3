#!/usr/bin/env python3
#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

import argparse
import gzip
import sys


def main():
    #
    parser = argparse.ArgumentParser()
    parser.add_argument('original_vcf')
    parser.add_argument('shifted_vcf')
    args = parser.parse_args()

    #
    original_variants = _read_vcf(args.original_vcf)
    shifted_variants = _read_vcf(args.shifted_vcf)

    #
    print('type\tcontig\tposition\treference\talternative')

    for key in (set(original_variants) - set(shifted_variants)):
        print('\t'.join(['VCF1_ONLY'] + list(key)))

    for key in (set(shifted_variants) - set(original_variants)):
        print('\t'.join(['VCF2_ONLY'] + list(key)))

    for key in (set(original_variants).intersection(set(shifted_variants))):
        if original_variants[key] != shifted_variants[key]:
            print('\t'.join(['GENOTYPE_MISMATCH'] + list(key)))


def _read_vcf(path):
    variants = {}
    with gzip.open(path, 'rt') as fin:
        for line in fin:
            if line.startswith('#'):
                continue

            cols = line.strip().split('\t')
            key = cols[0], cols[1], cols[3], cols[4]
            genotypes = tuple(c.split(':')[0] for c in cols[9:])
            variants[key] = genotypes

    return variants


if __name__ == '__main__':
    main()
