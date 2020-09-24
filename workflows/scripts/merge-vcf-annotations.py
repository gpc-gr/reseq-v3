#!/usr/bin/env python3
#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

import argparse
import json
import sys


def main():
    #
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--output-type', required=True, choices=('b', 'z'))
    parser.add_argument('--config', required=True)
    args = parser.parse_args()

    #
    commands = ['bcftools view --no-version {}'.format(args.source)]

    with open(args.config) as fin:
        for line in fin:
            #
            line = line.strip()
            if not line:
                continue

            #
            cols = line.split(':')
            if cols[0] == 'id':
                commands.append('SnpSift annotate -id {}'.format(cols[1]))
            elif cols[0] == 'info':
                commands.append('SnpSift annotate {}'.format(cols[1]))
            else:
                raise Exception

    commands.append(' && '.join([
        'bcftools view --no-version --output-type {} {}'.format(args.output_type, args.output),
        'bcftools index --{} {}'.format(
            'tbi' if args.output_type == 'z' else 'csi',
            args.output
        )
    ]))

    #
    script = ' | '.join(commands)
    print('[INFO] Running the following script:', file=sys.stderr)
    print('[INFO]     {}'.format(script), file=sys.stderr)

    subprocess.check_call(script, shell=True)


if __name__ == '__main__':
    main()
