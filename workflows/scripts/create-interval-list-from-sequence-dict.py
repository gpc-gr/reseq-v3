#!/usr/bin/env python3
#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

import argparse
import re
import sys


def main():
    #
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--autosome', action='store_true')
    group.add_argument('--chrX', action='store_true')
    group.add_argument('--chrY', action='store_true')
    group.add_argument('--mitochondria', action='store_true')
    args = parser.parse_args()

    #
    if args.autosome:
        check_contig_name = lambda v: re.match('(chr)?\d+', v) is not None
    elif args.chrX:
        check_contig_name = lambda v: re.match('(chr)?X', v) is not None
    elif args.chrY:
        check_contig_name = lambda v: re.match('(chr)?Y', v) is not None
    elif args.mitochondria:
        check_contig_name = lambda v: re.match('(chrM)|(MT)', v) is not None
    else:
        raise Exception

    #
    headers = []
    contigs = []

    for line in sys.stdin:
        line = line.strip()

        if line.startswith('@'):
            headers.append(line)

        if line.startswith('@SQ'):
            cols = line.split('\t')
            name = [c[3:] for c in cols if c.startswith('SN:')][0]
            length = [c[3:] for c in cols if c.startswith('LN:')][0]

            if check_contig_name(name):
                contigs.append((name, length))

    #
    for line in headers:
        print(line)

    for name, length in contigs:
        print('\t'.join([name, '1', length, '+', name]))


if __name__ == '__main__':
    main()
