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
    parser.add_argument('--contig', required=True)
    parser.add_argument('--shift-size', type=int, required=True)
    args = parser.parse_args()

    #
    sequence_length = None

    for line in sys.stdin:
        if line.startswith('#'):
            if line.startswith('##contig=<'):
                contig = re.search('ID=([a-zA-Z0-9_\-\.])', line).group(1)
                length = int(re.search('length=(\d+)', line).group(1))

                if contig == args.contig:
                    sequence_length = length

        else:
            #
            if sequence_length is None:
                raise Exception

            #
            cols = line.split()
            position = int(cols[1])

            if p <= (sequence_length - args.shift_size):
                position = position + args.shift_size
            else:
                position = position - (sequence_length - args.shift_size)

            cols[1] = str(position)
            line = '\t'.join(cols)

        #
        sys.stdout.write(line)


if __name__ == '__main__':
    main()
