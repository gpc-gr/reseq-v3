#!/usr/bin/env python3
#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

import argparse
import collections
import glob
import os


def main():
    #
    parser = argparse.ArgumentParser()
    parser.add_argument('prefix')
    args = parser.parse_args()

    #
    fastq_pairs = collections.defaultdict(list)
    for path in glob.glob(args.prefix + '.*.fastq.gz'):
        name = os.path.basename(path).replace('_1.fastq.gz', '').replace('_2.fastq.gz', '')
        id = name.split('.')[-1]
        fastq_pairs[id].append(os.path.abspath(path))

    #
    print('id\tread1\tread2')
    for id, paths in sorted(fastq_pairs.items()):
        assert len(paths) == 2
        print('\t'.join([id] + list(sorted(paths))))


if __name__ == '__main__':
    main()
