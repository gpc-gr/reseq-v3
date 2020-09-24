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
    parser.add_argument('--mapping', dest='mappings', action='append', default=[])
    args = parser.parse_args()

    #
    mappings = {}
    for entry in args.mappings:
        orig, new = entry.split(':')
        if orig != new:
            mappings[orig] = new

    #
    for line in sys.stdin:
        #
        if line.startswith('#'):
            if line.startswith('##INFO='):
                for orig, new in mappings.items():
                    line = line.replace('ID={},'.format(orig), 'ID={},'.format(new))

        else:
            cols = line.split('\t')
            for orig, new in mappings.items():
                cols[7] = cols[7].replace('{}='.format(orig), '{}='.format(new))

            line = '\t'.join(cols)

        #
        sys.stdout.write(line)


if __name__ == '__main__':
    main()
