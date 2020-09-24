#!/usr/bin/env python3
#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

import argparse
import csv
import sys


def main():
    #
    parser = argparse.ArgumentParser()
    parser.add_argument('original_sample_sheet')
    parser.add_argument('sex_prediction_result')
    args = parser.parse_args()

    #
    with open(args.sex_prediction_result) as fin:
        sample_sex_map = {r['id']: r['predicted_sex'] for r in csv.DictReader(fin, delimiter='\t')}

    #
    with open(args.original_sample_sheet) as fin:
        reader = csv.DictReader(fin, delimiter='\t')

        writer = csv.DictWriter(sys.stdout, fieldnames=reader.fieldnames, delimiter='\t')
        writer.writeheader()

        for record in reader:
            record['sex'] = sample_sex_map[record['id']]
            writer.writerow(record)


if __name__ == '__main__':
    main()
