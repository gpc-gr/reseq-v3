#!/usr/bin/env python3
#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

import argparse
import csv
import io
import os
import subprocess
import sys


def main():
    #
    parser = argparse.ArgumentParser()
    parser.add_argument('--threads', type=int, default=1)
    parser.add_argument('--inconsistent-variant-table', required=True)
    parser.add_argument('chunks', metavar='chunk', nargs='+')
    args = parser.parse_args()

    #
    variants_to_be_skipped = set()
    with open(args.inconsistent_variant_table) as fin:
        for record in csv.DictReader(fin, delimiter='\t'):
            key = '{contig}:{position}_{reference}_{alternative}'.format(**record)
            variants_to_be_skipped.add(key)

    #
    previous_position = 0
    for line in _concat_vcfs(sorted(args.chunks, key=os.path.basename), args.threads):
        if not line.startswith('#'):
            cols = line.strip().split('\t')

            key = '{}:{}_{}_{}'.format(cols[0], cols[1], cols[3], cols[4])
            if key in variants_to_be_skipped:
                print('[INFO] variant excluded: {}'.format(key), file=sys.stderr)

            position = int(cols[1])
            if position <= previous_position:
                continue

            previous_position = position

        sys.stdout.write(line)


def _concat_vcfs(vcfs, threads):
    command = [
        'bcftools', 'concat',
            '--no-version',
            '--threads', str(threads)
    ] + list(vcfs)

    process = subprocess.Popen(command, stdout=subprocess.PIPE, bufsize=-1)
    with io.open(process.stdout.fileno(), closefd=False) as fin:
        yield from fin

    process.wait()
    if process.returncode != 0:
        raise Exception('bcftools exited with status code: {}'.format(process.returncode))


if __name__ == '__main__':
    main()
