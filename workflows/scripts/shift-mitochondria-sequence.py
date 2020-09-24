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
    parser.add_argument('--shift-size', type=int, default=10000)
    args = parser.parse_args()

    #
    for header, sequence in _parse_fasta(sys.stdin):
        id = header.split()[0]
        if id in ('chrM', 'chrMT', 'MT'):
            sequence = sequence[args.shift_size:] + sequence[:args.shift_size]

        print(f'>{header}')
        for line in [sequence[i:i+100] for i in range(0, len(sequence), 100)]:
            print(line)

        print()


def _parse_fasta(fin):
    header = None
    sequences = None
    for line in fin:
        line = line.strip()
        if not line:
            continue

        if line.startswith('>'):
            if header:
                yield header, ''.join(sequences)

            header = line[1:]
            sequences = []

        else:
            sequences.append(line)

    if header:
        yield header, ''.join(sequences)


if __name__ == '__main__':
    main()
