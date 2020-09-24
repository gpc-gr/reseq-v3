#!/usr/bin/env python3
#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

import argparse


def main():
    #
    parser = argparse.ArgumentParser()
    parser.add_argument('--start', type=int)
    parser.add_argument('--end', type=int)
    parser.add_argument('--size', type=int)
    args = parser.parse_args()

    #
    index = 1
    start = args.start

    print('index\tstart\tend')
    while start <= args.end:
        end = min(start + args.size - 1, args.end)
        print('{:04d}\t{}\t{}'.format(index, start, end))

        index += 1
        start = end + 1


if __name__ == '__main__':
    main()
