#!/usr/bin/env python3
#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

import argparse
import gzip
import os
import re
import subprocess
import sys


def main():
    #
    parser = argparse.ArgumentParser()
    parser.add_argument('vcfs', metavar='vcf', nargs='+')
    args = parser.parse_args()

    #
    file_region_map = {}
    for path in args.vcfs:
        try:
            contig, start, end, padding = _get_chunk_region(path)
        except:
            continue

        file_region_map[path] = contig, start, end, padding

    #
    print('type\tcontig\tposition\treference\talternative\tvcf1\tvcf2')

    for path1, (contig1, start1, end1, padding1) in file_region_map.items():
        for path2, (contig2, start2, end2, padding2) in file_region_map.items():
            #
            if (path1 >= path2) or (contig1 != contig2) or (end1 != start2):
                continue

            #
            comp_contig = contig1
            comp_start = end1 - padding2
            comp_end = end1 + padding1
            comp_start2 = start2 - padding2
            comp_end2 = start2 + padding1
            comp_region = '{}:{}-{}'.format(comp_contig, comp_start, comp_end)
            assert (comp_start == comp_start2) and (comp_end == comp_end2)

            print('[INFO] chunk1={}, chunk2={}, start={}, end={}'.format(
                os.path.basename(path1), os.path.basename(path2), comp_start, comp_end
            ), file=sys.stderr)

            #
            variants1 = _read_vcf(path1, comp_region)
            variants2 = _read_vcf(path2, comp_region)

            for key in sorted(set(variants1) - set(variants2)):
                row = list(key) + [os.path.basename(path1), os.path.basename(path2), str(comp_start), str(comp_end)]
                print('VCF1_ONLY\t' + '\t'.join(row))

            for key in sorted(set(variants2) - set(variants1)):
                row = list(key) + [os.path.basename(path1), os.path.basename(path2), str(comp_start), str(comp_end)]
                print('VCF2_ONLY\t' + '\t'.join(row))

            for key in sorted(set(variants1).intersection(set(variants2))):
                if variants1[key] == variants2[key]:
                    continue

                row = list(key) + [os.path.basename(path1), os.path.basename(path2), str(comp_start), str(comp_end)]
                print('GENOTYPE_MISMATCH\t' + '\t'.join(row))


def _get_chunk_region(path):
    with gzip.open(path, 'rt') as fin:
        for line in fin:
            if line.startswith('##GATKCommandLine.GenotypeGVCFs'):
                return _extract_region(line)

    raise Exception


def _extract_region(line):
    contig = None
    start = None
    end = None
    padding = None

    for col in line.split():
        if col.startswith('intervals'):
            match = re.search('\[([a-zA-Z0-9_\.]+):(\d+)-(\d+)\]', col)
            contig = match.group(1)
            start = int(match.group(2))
            end = int(match.group(3))

        elif col.startswith('interval_padding'):
            padding = int(col.split('=')[1])

    for value in (contig, start, end, padding):
        assert value is not None

    return contig, start, end, padding


def _read_vcf(path, region):
    command = ['bcftools', 'view', '--no-version', '--regions', region, path]
    output = subprocess.check_output(command, shell=True).decode('utf-8')

    variants = {}
    for line in output.splitlines():
        if line.startswith('#'):
            continue

        cols = line.strip().split('\t')
        contig = cols[0]
        position = cols[1]
        reference = cols[3]
        alternatives = cols[4]
        genotypes = tuple(s.split(':')[0] for s in cols[9:])

        variants[contig, position, reference, alternatives] = genotypes

    return variants


if __name__ == '__main__':
    main()
